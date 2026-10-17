<#
.SYNOPSIS
    cli_tweaks - Windows uninstaller. Reverts what install.ps1 did, using the
    install manifest so it NEVER removes anything that was already present.
.DESCRIPTION
    Two modes:
      -Cosmetic  Revert configs/defaults only (restore backups, revert Windows
                 Terminal default profile + Windows default-terminal-app, clear
                 the bat theme cache and the profile's init cache).
                 Leaves all installed tools in place.
      -Full      Cosmetic, PLUS winget-uninstall the packages WE installed
                 (never the ones flagged pre-existing), remove the PowerShell
                 modules we saved (never pre-existing ones), the font
                 files/registry values we added, the data dirs our tools created,
                 and the dead user-PATH entries winget leaves behind.

    Safe to repeat: every reverted entry is dropped from the manifest, so
    running it twice, or -Cosmetic and later -Full, never deletes a restored
    original. A package that could not be removed stays in the manifest (and
    the manifest stays), so a re-run tries again.

    MSI-based packages (starship, ...) fail a silent uninstall without admin
    rights (exit 1603). Those are retried once through an elevated winget -
    expect a UAC prompt.

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
$InitCache    = Join-Path $env:LOCALAPPDATA 'cli_tweaks\cache'   # the profile's cached init scripts
$PkgRoot      = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'

function Write-Utf8NoBom([string]$Path, [string]$Text) {
    [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($false)))
}

# Same as install.ps1: find a tool even if this session's PATH misses it.
function Find-Tool([string]$Name, [string[]]$Globs) {
    $c = Get-Command $Name -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    foreach ($g in $Globs) {
        $f = Get-Item $g -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($f) { return $f.FullName }
    }
    return $null
}

function Test-WingetInstalled([string]$Id) {
    $out = (winget list --id $Id --exact --accept-source-agreements 2>$null | Out-String)
    return ($out -match [regex]::Escape($Id))
}

function Test-IsAdmin {
    $p = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
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
        (Join-Path $HOME '.config\wezterm\wezterm.lua'),
        (Join-Path $HOME '.config\cli_tweaks\keys.txt'),
        (Join-Path $HOME '.config\cli_tweaks\lesskey'),
        (Join-Path $env:APPDATA 'alacritty\alacritty.toml')
    ) | ForEach-Object {
        $bak = Get-ChildItem "$_*.bak.*" -ErrorAction SilentlyContinue | Select-Object -Expand FullName
        "  {0}{1}" -f $_, $(if ($bak) { "   (backups: $($bak -join ', '))" } else { '' })
    }
    exit 1   # nothing was reverted - same as Ubuntu24/uninstall.sh
}

$man = Get-Content $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
Write-Host ("Loaded manifest ({0} packages, {1} files, {2} fonts)" -f @($man.packages).Count, @($man.files).Count, @($man.fonts).Count) -ForegroundColor Cyan

function Save-ManifestNow {
    if (-not $WhatIfPreference) { Write-Utf8NoBom $ManifestPath ($man | ConvertTo-Json -Depth 6) }
}
# Set a manifest field even if this (older) manifest does not have it yet:
# plain assignment to a missing property of a JSON object throws.
function Set-ManifestField([string]$Name, $Value) {
    $man | Add-Member -NotePropertyName $Name -NotePropertyValue $Value -Force
}

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
Set-ManifestField 'files' @($keepFiles)

# 4. bat's theme cache: built by -Configs from themes that are gone now.
if ($man.batCache) {
    $bat = Find-Tool 'bat' @("$PkgRoot\sharkdp.bat*\*\bat.exe")
    if ($bat -and $PSCmdlet.ShouldProcess('bat cache', 'clear')) {
        & $bat cache --clear 2>&1 | Out-Null
        Write-Host "  bat cache cleared" -ForegroundColor Green
    }
    if (-not $WhatIfPreference) { $man.batCache = $false }
}

# 5. The profile's cached starship/zoxide init scripts (rebuilt on demand).
if ((Test-Path $InitCache) -and $PSCmdlet.ShouldProcess($InitCache, 'remove init cache')) {
    Remove-Item $InitCache -Recurse -Force
    Write-Host "  removed $InitCache" -ForegroundColor Green
}

# Persist what was reverted. Without this the manifest still lists every file
# after -Cosmetic, so a second run (or -Cosmetic followed by -Full) would find
# the backups gone and treat your restored originals as ours. Dropping the
# entries also lets a later install.ps1 record fresh backups of them.
Save-ManifestNow

if ($Cosmetic) {
    Write-Host "`nCosmetic revert complete. Tools left installed." -ForegroundColor Green
    exit 0
}

# ===========================================================================
# FULL: also remove tools / modules / fonts / dirs we installed
# ===========================================================================

# 6. PowerShell modules (PSFzf; posh-git from older installs) - only those WE
# saved. Entries written before the preexisting flag existed carry none and
# are treated as ours, as they always were.
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

# 7. Fonts (only the files + registry values we added). A font flagged
# preexisting was there before our first install and is kept. Removing the
# registry value first unregisters the font; a file still held open by a
# running terminal cannot be deleted - say so instead of failing silently.
$fontsRemoved = 0
foreach ($ft in @($man.fonts)) {
    if (-not $ft) { continue }
    if ($ft.preexisting) { continue }
    $fontsRemoved++
    if ($ft.regValue -and $man.fontRegKey) {
        if ($PSCmdlet.ShouldProcess("$($man.fontRegKey)\$($ft.regValue)", "remove font registry value")) {
            Remove-ItemProperty -Path $man.fontRegKey -Name $ft.regValue -ErrorAction SilentlyContinue
        }
    }
    if ($ft.file -and (Test-Path $ft.file)) {
        if ($PSCmdlet.ShouldProcess($ft.file, "remove font file")) {
            try { Remove-Item $ft.file -Force -ErrorAction Stop }
            catch { Write-Host "  font file in use, delete it after closing terminals: $($ft.file)" -ForegroundColor DarkYellow }
        }
    }
}
if ($fontsRemoved) { Write-Host "  removed $fontsRemoved font entries we added." -ForegroundColor Green }

# 8. tldr's downloaded pages - before tealdeer itself goes (only if WE
# installed it; its cache dir is tealdeer's business, so ask tealdeer).
$tealdeer = @($man.packages) | Where-Object { $_ -and $_.id -eq 'dbrgn.tealdeer' -and -not $_.preexisting }
if ($tealdeer) {
    $tldr = Find-Tool 'tldr' @("$PkgRoot\dbrgn.tealdeer*\tldr.exe", "$env:LOCALAPPDATA\Microsoft\WinGet\Links\tldr.exe")
    if ($tldr -and $PSCmdlet.ShouldProcess('tldr cache', 'clear')) {
        & $tldr --clear-cache 2>&1 | Out-Null
        Write-Host "  tldr pages cleared" -ForegroundColor Green
    }
}

# 9. winget packages - ONLY those we installed (never pre-existing ones).
# Success is judged by `winget list` afterwards, not by the exit code. A
# package that is still there after an elevated retry stays in the manifest.
$keepPkgs = New-Object System.Collections.ArrayList
$failed   = $false   # a package we tried to remove is still there
foreach ($p in @($man.packages)) {
    if (-not $p) { continue }
    if ($p.preexisting) {
        Write-Host "  skip $($p.id) (was already installed before)" -ForegroundColor DarkGray
        continue
    }
    if ($p.id -eq 'Microsoft.PowerShell' -and -not $Yes) {
        Write-Host "  skip Microsoft.PowerShell (pass -Yes to also remove PowerShell 7)" -ForegroundColor DarkYellow
        [void]$keepPkgs.Add($p)
        continue
    }
    if (-not $PSCmdlet.ShouldProcess($p.id, "winget uninstall")) { [void]$keepPkgs.Add($p); continue }
    if (-not (Test-WingetInstalled $p.id)) {
        Write-Host "  $($p.id) is already gone" -ForegroundColor DarkGray
        continue
    }
    Write-Host "  winget uninstall $($p.id)" -ForegroundColor Cyan
    winget uninstall --id $p.id --exact --silent --accept-source-agreements --disable-interactivity
    if ((Test-WingetInstalled $p.id) -and -not (Test-IsAdmin)) {
        # MSI packages (starship, ...) need admin for a silent uninstall (1603).
        Write-Host "    failed without admin rights - retrying elevated (UAC prompt)" -ForegroundColor DarkYellow
        try {
            Start-Process winget -Verb RunAs -Wait -ArgumentList @(
                'uninstall', '--id', $p.id, '--exact', '--silent',
                '--accept-source-agreements', '--disable-interactivity')
        } catch { Write-Host "    elevation declined" -ForegroundColor DarkYellow }
    }
    if (Test-WingetInstalled $p.id) {
        Write-Host "  WARNING: $($p.id) is still installed - kept in the manifest, re-run later" -ForegroundColor Red
        [void]$keepPkgs.Add($p)
        $failed = $true
    }
}
Set-ManifestField 'packages' @($keepPkgs)

# 10. Dead user-PATH entries. winget adds one PATH entry per portable package
# (...\WinGet\Packages\<id>_...) and does not always take it out again. Only
# entries under that folder whose directory no longer exists are dropped;
# the raw (unexpanded) value is edited and its REG_EXPAND_SZ type kept.
$envKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment', $true)
if ($envKey) {
    $kind  = $envKey.GetValueKind('Path')
    $raw   = [string]$envKey.GetValue('Path', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
    $parts = $raw -split ';'
    $dead  = @($parts | Where-Object { $_ -like '*\Microsoft\WinGet\Packages\*' -and -not (Test-Path ([Environment]::ExpandEnvironmentVariables($_))) })
    if ($dead.Count -and $PSCmdlet.ShouldProcess('user PATH', "remove $($dead.Count) dead winget entries")) {
        $envKey.SetValue('Path', (($parts | Where-Object { $dead -notcontains $_ }) -join ';'), $kind)
        $dead | ForEach-Object { Write-Host "  PATH: removed dead entry $_" -ForegroundColor Green }
    }
    $envKey.Close()
}

# 11. Data dirs our tools created (e.g. ~\.local\share\wezterm) - only those
# that did not exist before the install.
$keepDirs = New-Object System.Collections.ArrayList
foreach ($d in @($man.dirs)) {
    if (-not $d) { continue }
    if ($d.preexisting) { continue }
    if (Test-Path $d.path) {
        if ($PSCmdlet.ShouldProcess($d.path, 'remove directory')) {
            try { Remove-Item $d.path -Recurse -Force -ErrorAction Stop; Write-Host "  removed $($d.path)" -ForegroundColor Green }
            catch { Write-Host "  could not remove $($d.path) (in use?) - kept in the manifest" -ForegroundColor DarkYellow; [void]$keepDirs.Add($d); $failed = $true }
        } else { [void]$keepDirs.Add($d) }
    }
}
Set-ManifestField 'dirs'    @($keepDirs)
Set-ManifestField 'modules' @()
Set-ManifestField 'fonts'   @()

# 12. The manifest itself - only when nothing is left. What is left is either
# a failure (exit 1, re-run later) or PowerShell 7 skipped without -Yes (the
# manifest stays so a later `-Full -Yes` can still remove it).
if (@($man.packages).Count -or @($man.dirs).Count) {
    Save-ManifestNow
    if ($failed) {
        Write-Host "`nFull uninstall finished with leftovers (see warnings) - manifest kept for a re-run." -ForegroundColor Yellow
        exit 1
    }
    Write-Host "`nFull uninstall complete (PowerShell 7 kept - pass -Yes to remove it too)." -ForegroundColor Green
    exit 0
}
if ($PSCmdlet.ShouldProcess($ManifestPath, "remove manifest")) {
    Remove-Item $ManifestPath -Force -ErrorAction SilentlyContinue
    $dir = Split-Path $ManifestPath
    if ((Get-ChildItem $dir -ErrorAction SilentlyContinue | Measure-Object).Count -eq 0) {
        Remove-Item $dir -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "`nFull uninstall complete. Open a new terminal: PATH changes apply to new processes." -ForegroundColor Green
exit 0
