<#
.SYNOPSIS
    cli_tweaks - Windows 11 installer (native PowerShell 7 experience).
.DESCRIPTION
    Mirrors the Ubuntu24 install.sh component model, using winget. Everything is
    per-user (no admin needed for tools/fonts). Existing files are backed up.

    Writes an install manifest to %LOCALAPPDATA%\cli_tweaks\install-manifest.json
    recording exactly what it installed / changed, so uninstall.ps1 can revert
    precisely and NEVER remove something that was already present beforehand.

    NOTE: run under Windows PowerShell 5.1 (to bootstrap pwsh7). Keep this file
    ASCII-only: 5.1 reads a no-BOM .ps1 as ANSI, turning non-ASCII punctuation
    into phantom string delimiters and breaking parsing.
.EXAMPLE
    ./install.ps1 -All
.EXAMPLE
    ./install.ps1 -Shell -Packages -Starship -Configs -Alacritty
.EXAMPLE
    ./install.ps1 -All -SetWindowsDefaultTerminalApp
.NOTES
    STATUS: tested on Windows 11 / Windows PowerShell 5.1 / pwsh 7.6.
#>
[CmdletBinding()]
param(
    [switch]$All,
    [switch]$Shell,                        # install PowerShell 7 (pwsh)
    [switch]$Packages,                     # fzf eza zoxide fd ripgrep bat btop
    [switch]$Fonts,                        # FiraCode Nerd Font (per-user)
    [switch]$Starship,                     # starship + shared starship.toml
    [switch]$Configs,                      # deploy the PowerShell profile
    [switch]$Alacritty,                    # alacritty + shared config (+ pwsh shell)
    [switch]$SetDefaultTerminal,           # Windows Terminal default profile -> pwsh7
    [switch]$SetWindowsDefaultTerminalApp  # opt-in: Windows "Default terminal app" -> WT
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$Shared   = Join-Path $RepoRoot 'shared'

# --- manifest ---------------------------------------------------------------
$ManifestDir  = Join-Path $env:LOCALAPPDATA 'cli_tweaks'
$ManifestPath = Join-Path $ManifestDir 'install-manifest.json'
$FontRegKey   = 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
$WtSettings   = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'
# Windows Terminal delegation GUIDs (for "Default terminal application").
$WtDelegationConsole  = '{2EACA947-7F5F-4CFA-BA87-8F7FBEEFBE69}'
$WtDelegationTerminal = '{E12CFF52-A866-4C77-9A90-F570A7AA2C6B}'

$Packages_ = New-Object System.Collections.ArrayList
$Files_    = New-Object System.Collections.ArrayList
$Modules_  = New-Object System.Collections.ArrayList
$Fonts_    = New-Object System.Collections.ArrayList
$Wt_       = $null    # {path, backup, prevDefaultProfile, newDefaultProfile}
$WinTerm_  = $null    # {prevConsole, prevTerminal}

# Seed from an existing manifest so re-runs accumulate and we never lose the
# ORIGINAL 'prev' values recorded on the first run.
if (Test-Path $ManifestPath) {
    try {
        $old = Get-Content $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($x in @($old.packages)) { if ($x) { [void]$Packages_.Add($x) } }
        foreach ($x in @($old.files))    { if ($x) { [void]$Files_.Add($x) } }
        foreach ($x in @($old.modules))  { if ($x) { [void]$Modules_.Add($x) } }
        foreach ($x in @($old.fonts))    { if ($x) { [void]$Fonts_.Add($x) } }
        if ($old.wt)                 { $Wt_ = $old.wt }
        if ($old.windowsTerminalApp) { $WinTerm_ = $old.windowsTerminalApp }
    } catch { Write-Host "  (could not read existing manifest; starting fresh)" -ForegroundColor DarkYellow }
}

function Write-Utf8NoBom([string]$Path, [string]$Text) {
    [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($false)))
}

# Move an existing file aside (used when we replace it with our own copy).
function Backup-Move([string]$Path) {
    if (Test-Path $Path) {
        $bak = "$Path.bak.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Write-Host "  backup $Path -> $bak" -ForegroundColor DarkGray
        Move-Item $Path $bak
        return $bak
    }
    return $null
}

# Copy an existing file aside (used when we edit it in place, e.g. WT settings).
function Backup-Copy([string]$Path) {
    if (Test-Path $Path) {
        $bak = "$Path.bak.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Write-Host "  backup $Path -> $bak" -ForegroundColor DarkGray
        Copy-Item $Path $bak -Force
        return $bak
    }
    return $null
}

function Register-Package([string]$Id, [bool]$Pre) {
    if (-not ($Packages_ | Where-Object { $_.id -eq $Id })) {
        [void]$Packages_.Add([pscustomobject]@{ id = $Id; preexisting = $Pre })
    }
}
function Register-File([string]$Path, $Backup) {
    if (-not ($Files_ | Where-Object { $_.path -eq $Path })) {
        [void]$Files_.Add([pscustomobject]@{ path = $Path; backup = $Backup })
    }
}
function Register-Module([string]$Name, [string]$Path) {
    if (-not ($Modules_ | Where-Object { $_.name -eq $Name })) {
        [void]$Modules_.Add([pscustomobject]@{ name = $Name; path = $Path })
    }
}
function Register-Font([string]$File, [string]$RegValue) {
    if (-not ($Fonts_ | Where-Object { $_.file -eq $File })) {
        [void]$Fonts_.Add([pscustomobject]@{ file = $File; regValue = $RegValue })
    }
}

function Get-PwshPath {
    $c = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    foreach ($p in @("$env:ProgramFiles\PowerShell\7\pwsh.exe",
                     "$env:LOCALAPPDATA\Microsoft\WindowsApps\pwsh.exe")) {
        if (Test-Path $p) { return $p }
    }
    return $null
}

function Test-WingetInstalled([string]$Id) {
    $out = (winget list --id $Id --exact --accept-source-agreements 2>$null | Out-String)
    return ($out -match [regex]::Escape($Id))
}

function Winget-Install([string]$Id) {
    $pre = Test-WingetInstalled $Id
    Write-Host ("  winget install {0}{1}" -f $Id, $(if ($pre) { '  (already present - will not be removed on uninstall)' } else { '' })) -ForegroundColor Cyan
    winget install --id $Id --exact --accept-source-agreements --accept-package-agreements --silent
    Register-Package $Id $pre
}

function Copy-Config([string]$Src, [string]$Dst) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Dst) | Out-Null
    $bak = Backup-Move $Dst
    Copy-Item $Src $Dst -Force
    Register-File $Dst $bak
    Write-Host "  installed $Dst" -ForegroundColor Green
}

function Get-WtPwshProfileGuid($settings) {
    $list = $settings.profiles.list
    $p = $list | Where-Object { $_.source -eq 'Windows.Terminal.PowershellCore' } | Select-Object -First 1
    if (-not $p) { $p = $list | Where-Object { $_.name -eq 'PowerShell' } | Select-Object -First 1 }
    if (-not $p) { $p = $list | Where-Object { $_.commandline -match 'pwsh' } | Select-Object -First 1 }
    if ($p) { return $p.guid } else { return $null }
}

function Save-Manifest {
    New-Item -ItemType Directory -Force -Path $ManifestDir | Out-Null
    $m = [pscustomobject]@{
        version             = 1
        updated             = (Get-Date -Format o)
        repoRoot            = $RepoRoot
        fontRegKey          = $FontRegKey
        packages            = @($Packages_)
        files               = @($Files_)
        modules             = @($Modules_)
        fonts               = @($Fonts_)
        wt                  = $Wt_
        windowsTerminalApp  = $WinTerm_
    }
    Write-Utf8NoBom $ManifestPath ($m | ConvertTo-Json -Depth 6)
    Write-Host "  manifest -> $ManifestPath" -ForegroundColor DarkGray
}

if (-not ($All -or $Shell -or $Packages -or $Fonts -or $Starship -or $Configs -or $Alacritty -or $SetDefaultTerminal -or $SetWindowsDefaultTerminalApp)) {
    Get-Help $PSCommandPath -Detailed
    exit 1
}

# --- PowerShell 7 ----------------------------------------------------------
if ($All -or $Shell) {
    Write-Host "== PowerShell 7 ==" -ForegroundColor Yellow
    Winget-Install 'Microsoft.PowerShell'
    Write-Host "  NOTE: reopen in 'pwsh' (not Windows PowerShell 5.1) after install." -ForegroundColor DarkYellow
}

# --- CLI packages ----------------------------------------------------------
if ($All -or $Packages) {
    Write-Host "== CLI packages ==" -ForegroundColor Yellow
    $ids = @(
        'junegunn.fzf',            # fuzzy finder
        'sharkdp.fd',              # fd (fzf backend / fin)
        'eza-community.eza',       # ls replacement w/ icons
        'ajeetdsouza.zoxide',      # smarter cd (z)
        'BurntSushi.ripgrep.MSVC', # rg
        'sharkdp.bat',             # bat
        'aristocratos.btop4win'    # btop (command name on Windows is btop4win)
    )
    foreach ($id in $ids) { Winget-Install $id }

    # PSFzf must land in pwsh7's module scope (Documents\PowerShell\Modules), NOT
    # 5.1's. Save it straight there. (Piping an inline -Command into pwsh from
    # 5.1 mangles quotes, so we only ask pwsh for its module path.)
    if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
        Install-PackageProvider -Name NuGet -Scope CurrentUser -Force | Out-Null
    }
    if ((Get-PSRepository -Name PSGallery).InstallationPolicy -ne 'Trusted') {
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    }
    $pwshPath = Get-PwshPath
    if ($pwshPath) {
        $pwshProfile = & $pwshPath -NoProfile -Command '$PROFILE.CurrentUserAllHosts'
        $modDir = Join-Path (Split-Path $pwshProfile) 'Modules'
        New-Item -ItemType Directory -Force -Path $modDir | Out-Null
        if (Test-Path (Join-Path $modDir 'PSFzf')) {
            Write-Host "  PSFzf already present in pwsh7 scope." -ForegroundColor DarkGray
        } else {
            Write-Host "  PSFzf module -> $modDir" -ForegroundColor Cyan
            Save-Module -Name PSFzf -Path $modDir -Force
        }
        Register-Module 'PSFzf' (Join-Path $modDir 'PSFzf')
    } else {
        Write-Host "  pwsh7 not found. Run './install.ps1 -Shell' first, then re-run '-Packages'." -ForegroundColor DarkYellow
    }
}

# --- Starship --------------------------------------------------------------
if ($All -or $Starship) {
    Write-Host "== Starship ==" -ForegroundColor Yellow
    Winget-Install 'Starship.Starship'
    Copy-Config (Join-Path $Shared 'starship.toml') (Join-Path $HOME '.config\starship.toml')
}

# --- PowerShell profile ----------------------------------------------------
if ($All -or $Configs) {
    Write-Host "== PowerShell profile ==" -ForegroundColor Yellow
    $pwshProfile = Join-Path $HOME 'Documents\PowerShell\profile.ps1'
    Copy-Config (Join-Path $PSScriptRoot 'Microsoft.PowerShell_profile.ps1') $pwshProfile
}

# --- Alacritty (shared config + Windows pwsh-shell overlay) ----------------
if ($All -or $Alacritty) {
    Write-Host "== Alacritty ==" -ForegroundColor Yellow
    Winget-Install 'Alacritty.Alacritty'
    $dst = Join-Path $env:APPDATA 'alacritty\alacritty.toml'
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dst) | Out-Null
    $bak  = Backup-Move $dst
    $base = (Get-Content (Join-Path $Shared 'alacritty.toml') -Raw).TrimEnd()
    $over = Get-Content (Join-Path $PSScriptRoot 'alacritty-windows.toml') -Raw
    Write-Utf8NoBom $dst ($base + "`r`n`r`n" + $over)
    Register-File $dst $bak
    Write-Host "  installed $dst (with pwsh shell overlay)" -ForegroundColor Green
}

# --- Fonts (FiraCode Nerd Font, per-user) ----------------------------------
if ($All -or $Fonts) {
    Write-Host "== FiraCode Nerd Font ==" -ForegroundColor Yellow
    $tmp = New-Item -ItemType Directory -Force -Path (Join-Path $env:TEMP "firacode_$(Get-Random)")
    $zip = Join-Path $tmp 'FiraCode.zip'
    Invoke-WebRequest -Uri 'https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip' -OutFile $zip
    Expand-Archive $zip -DestinationPath $tmp -Force
    $fontDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
    New-Item -ItemType Directory -Force -Path $fontDir | Out-Null
    Get-ChildItem $tmp -Filter '*.ttf' -Recurse | ForEach-Object {
        $dest = Join-Path $fontDir $_.Name
        Copy-Item $_.FullName $dest -Force
        $regVal = "$($_.BaseName) (TrueType)"
        New-ItemProperty -Path $FontRegKey -Name $regVal -Value $dest -PropertyType String -Force | Out-Null
        Register-Font $dest $regVal
    }
    Remove-Item $tmp -Recurse -Force
    Write-Host "  FiraCode Nerd Font installed (per-user)." -ForegroundColor Green
}

# --- Windows Terminal default profile -> PowerShell 7 ----------------------
if ($All -or $SetDefaultTerminal) {
    Write-Host "== Windows Terminal default profile -> PowerShell 7 ==" -ForegroundColor Yellow
    if (Test-Path $WtSettings) {
        $json = Get-Content $WtSettings -Raw -Encoding UTF8 | ConvertFrom-Json
        $guid = Get-WtPwshProfileGuid $json
        if ($guid) {
            $prev = [string]$json.defaultProfile
            $bak  = Backup-Copy $WtSettings
            $raw  = Get-Content $WtSettings -Raw -Encoding UTF8
            if ($raw -match '"defaultProfile"\s*:') {
                $new = [regex]::Replace($raw, '("defaultProfile"\s*:\s*)"[^"]*"', ('${1}"' + $guid + '"'))
            } else {
                $new = [regex]::Replace($raw, '\{', ("{`r`n    " + '"defaultProfile": "' + $guid + '",'), 1)
            }
            Write-Utf8NoBom $WtSettings $new
            # preserve the ORIGINAL prev value across re-runs
            if (-not $Wt_) {
                $Wt_ = [pscustomobject]@{ path = $WtSettings; backup = $bak; prevDefaultProfile = $prev; newDefaultProfile = $guid }
            } else {
                $Wt_.newDefaultProfile = $guid
            }
            Write-Host "  defaultProfile set to pwsh7 ($guid). Prev was $prev." -ForegroundColor Green
        } else {
            Write-Host "  Could not find a PowerShell 7 profile in Windows Terminal - skipped." -ForegroundColor DarkYellow
        }
    } else {
        Write-Host "  Windows Terminal settings.json not found - skipped." -ForegroundColor DarkYellow
    }
}

# --- Windows "Default terminal application" -> Windows Terminal (opt-in) ----
if ($SetWindowsDefaultTerminalApp) {
    Write-Host "== Windows default terminal application -> Windows Terminal ==" -ForegroundColor Yellow
    $startup = 'HKCU:\Console\%%Startup'
    $prevC = (Get-ItemProperty $startup -Name DelegationConsole  -ErrorAction SilentlyContinue).DelegationConsole
    $prevT = (Get-ItemProperty $startup -Name DelegationTerminal -ErrorAction SilentlyContinue).DelegationTerminal
    New-Item -Path $startup -Force | Out-Null
    Set-ItemProperty -Path $startup -Name DelegationConsole  -Value $WtDelegationConsole
    Set-ItemProperty -Path $startup -Name DelegationTerminal -Value $WtDelegationTerminal
    if (-not $WinTerm_) {
        $WinTerm_ = [pscustomobject]@{ prevConsole = [string]$prevC; prevTerminal = [string]$prevT }
    }
    Write-Host "  Set. Prev console=$prevC terminal=$prevT" -ForegroundColor Green
}

Save-Manifest
Write-Host "`nDone." -ForegroundColor Green
exit 0   # avoid leaking a stray non-zero $LASTEXITCODE from winget subcommands
