<#
.SYNOPSIS
    cli_tweaks - Windows uninstaller. Reverts what install.ps1 did, using the
    install manifest so it NEVER removes anything that was already present.
.DESCRIPTION
    Two modes:
      -Cosmetic  Revert configs/defaults only (restore backups, revert Windows
                 Terminal default profile + Windows default-terminal-app).
                 Leaves all installed tools in place.
      -Full      Cosmetic, PLUS winget-uninstall the packages WE installed
                 (never the ones flagged pre-existing), remove the PSFzf and
                 posh-git modules we saved (never pre-existing ones), and
                 remove only the font files/registry values we added.

    Safe to repeat: -Cosmetic drops what it reverted from the manifest, so
    running it twice, or -Cosmetic and later -Full, never deletes a restored
    original.

    Supports -WhatIf for a dry run. PowerShell 7 (pwsh) is only removed when you
    pass -Yes (it is the shell you are likely running in).

    ASCII-only (see install.ps1 note) - may be run under Windows PowerShell 5.1.
.EXAMPLE
    ./uninstall.ps1 -Cosmetic -WhatIf
.EXAMPLE
    ./uninstall.ps1 -Full -Yes
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [switch]$Cosmetic,
    [switch]$Full,
    [switch]$Yes   # also remove PowerShell 7 during -Full
)

$ManifestPath = Join-Path $env:LOCALAPPDATA 'cli_tweaks\install-manifest.json'

function Write-Utf8NoBom([string]$Path, [string]$Text) {
    [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($false)))
}

if (-not ($Cosmetic -or $Full)) {
    Get-Help $PSCommandPath -Detailed
    exit 1
}
if ($Cosmetic -and $Full) { $Cosmetic = $false }   # Full is a superset

# --- No manifest: conservative fallback ------------------------------------
if (-not (Test-Path $ManifestPath)) {
    Write-Host "No install manifest found at $ManifestPath." -ForegroundColor Yellow
    Write-Host "This uninstaller only removes what a manifest-writing install recorded," -ForegroundColor Yellow
    Write-Host "so it will not guess. Known config locations to check by hand:" -ForegroundColor Yellow
    @(
        (Join-Path $HOME 'Documents\PowerShell\profile.ps1'),
        (Join-Path $HOME '.config\starship.toml'),
        (Join-Path $env:APPDATA 'alacritty\alacritty.toml')
    ) | ForEach-Object {
        $bak = Get-ChildItem "$_*.bak.*" -ErrorAction SilentlyContinue | Select-Object -Expand FullName
        "  {0}{1}" -f $_, $(if ($bak) { "   (backups: $($bak -join ', '))" } else { '' })
    }
    exit 1   # nothing was reverted - same as Ubuntu24/uninstall.sh
}

$man = Get-Content $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
Write-Host ("Loaded manifest ({0} packages, {1} files, {2} fonts)" -f @($man.packages).Count, @($man.files).Count, @($man.fonts).Count) -ForegroundColor Cyan

# ===========================================================================
# COSMETIC revert (runs for both -Cosmetic and -Full)
# ===========================================================================

# 1. Windows Terminal default profile -> previous value
if ($man.wt -and $man.wt.prevDefaultProfile -and (Test-Path $man.wt.path)) {
    $prev = [string]$man.wt.prevDefaultProfile
    $raw  = Get-Content $man.wt.path -Raw -Encoding UTF8
    if ($raw -match '"defaultProfile"\s*:') {
        $new = [regex]::Replace($raw, '("defaultProfile"\s*:\s*)"[^"]*"', ('${1}"' + $prev + '"'))
        if ($PSCmdlet.ShouldProcess($man.wt.path, "restore WT defaultProfile to $prev")) {
            Write-Utf8NoBom $man.wt.path $new
            Write-Host "  WT defaultProfile restored to $prev" -ForegroundColor Green
            $man.wt = $null     # done - see "Persist" below
        }
    }
}

# 2. Windows "Default terminal application" -> previous value
if ($man.windowsTerminalApp) {
    $startup = 'HKCU:\Console\%%Startup'
    $pc = [string]$man.windowsTerminalApp.prevConsole;  if (-not $pc) { $pc = '{00000000-0000-0000-0000-000000000000}' }
    $pt = [string]$man.windowsTerminalApp.prevTerminal; if (-not $pt) { $pt = '{00000000-0000-0000-0000-000000000000}' }
    if ($PSCmdlet.ShouldProcess($startup, "restore DelegationConsole=$pc DelegationTerminal=$pt")) {
        New-Item -Path $startup -Force | Out-Null
        Set-ItemProperty -Path $startup -Name DelegationConsole  -Value $pc
        Set-ItemProperty -Path $startup -Name DelegationTerminal -Value $pt
        Write-Host "  Windows default terminal app restored." -ForegroundColor Green
        $man.windowsTerminalApp = $null
    }
}

# 3. Config files: restore backup if we had one, else remove our file.
#
# A file is removed ONLY when the manifest says no original ever existed
# (backup = null). A recorded backup that is missing on disk is NOT the same
# thing: it usually means an earlier run already moved it back, so the file at
# $f.path IS your original - removing it would destroy it. Warn and leave it.
$keepFiles = New-Object System.Collections.ArrayList
foreach ($f in @($man.files)) {
    if (-not $f) { continue }
    if ($f.backup -and (Test-Path $f.backup)) {
        if ($PSCmdlet.ShouldProcess($f.path, "restore original from $($f.backup)")) {
            Move-Item $f.backup $f.path -Force
            Write-Host "  restored $($f.path)" -ForegroundColor Green
        } else { [void]$keepFiles.Add($f) }
    } elseif ($f.backup) {
        Write-Host "  skip $($f.path): recorded backup $($f.backup) is gone - leaving the file as is" -ForegroundColor DarkYellow
        [void]$keepFiles.Add($f)
    } elseif (Test-Path $f.path) {
        if ($PSCmdlet.ShouldProcess($f.path, "remove (no prior version existed)")) {
            Remove-Item $f.path -Force
            Write-Host "  removed $($f.path)" -ForegroundColor Green
        } else { [void]$keepFiles.Add($f) }
    }
}

# Persist what was reverted. Without this the manifest still lists every file
# after -Cosmetic, so a second run (or -Cosmetic followed by -Full) would find
# the backups gone and treat your restored originals as ours. Dropping the
# entries also lets a later install.ps1 record fresh backups of them.
$man.files = @($keepFiles)
if (-not $WhatIfPreference) {
    Write-Utf8NoBom $ManifestPath ($man | ConvertTo-Json -Depth 6)
}

if ($Cosmetic) {
    Write-Host "`nCosmetic revert complete. Tools left installed." -ForegroundColor Green
    exit 0
}

# ===========================================================================
# FULL: also remove tools / modules / fonts we installed
# ===========================================================================

# 4. PowerShell modules (PSFzf, posh-git) - only those WE saved. Entries
# written before the preexisting flag existed carry none and are treated as
# ours, as they always were.
foreach ($mod in @($man.modules)) {
    if ($mod -and $mod.preexisting) {
        Write-Host "  skip module $($mod.name) (was already installed before)" -ForegroundColor DarkGray
        continue
    }
    if ($mod -and $mod.path -and (Test-Path $mod.path)) {
        if ($PSCmdlet.ShouldProcess($mod.path, "remove module $($mod.name)")) {
            Remove-Item $mod.path -Recurse -Force
            Write-Host "  removed module $($mod.name)" -ForegroundColor Green
        }
    }
}

# 5. Fonts (only the files + registry values we added). A font flagged
# preexisting was there before our first install and is kept; entries written
# before that flag existed carry none and count as ours.
$fontsRemoved = 0
foreach ($ft in @($man.fonts)) {
    if (-not $ft) { continue }
    if ($ft.preexisting) { continue }
    $fontsRemoved++
    if ($ft.file -and (Test-Path $ft.file)) {
        if ($PSCmdlet.ShouldProcess($ft.file, "remove font file")) { Remove-Item $ft.file -Force }
    }
    if ($ft.regValue -and $man.fontRegKey) {
        if ($PSCmdlet.ShouldProcess("$($man.fontRegKey)\$($ft.regValue)", "remove font registry value")) {
            Remove-ItemProperty -Path $man.fontRegKey -Name $ft.regValue -ErrorAction SilentlyContinue
        }
    }
}
if ($fontsRemoved) { Write-Host "  removed $fontsRemoved font entries we added." -ForegroundColor Green }

# 6. winget packages - ONLY those we installed (never pre-existing ones)
foreach ($p in @($man.packages)) {
    if (-not $p) { continue }
    if ($p.preexisting) {
        Write-Host "  skip $($p.id) (was already installed before)" -ForegroundColor DarkGray
        continue
    }
    if ($p.id -eq 'Microsoft.PowerShell' -and -not $Yes) {
        Write-Host "  skip Microsoft.PowerShell (pass -Yes to also remove PowerShell 7)" -ForegroundColor DarkYellow
        continue
    }
    if ($PSCmdlet.ShouldProcess($p.id, "winget uninstall")) {
        Write-Host "  winget uninstall $($p.id)" -ForegroundColor Cyan
        winget uninstall --id $p.id --exact --silent --accept-source-agreements
    }
}

# 7. Remove the manifest itself
if ($PSCmdlet.ShouldProcess($ManifestPath, "remove manifest")) {
    Remove-Item $ManifestPath -Force -ErrorAction SilentlyContinue
    $dir = Split-Path $ManifestPath
    if ((Get-ChildItem $dir -ErrorAction SilentlyContinue | Measure-Object).Count -eq 0) {
        Remove-Item $dir -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "`nFull uninstall complete." -ForegroundColor Green
exit 0
