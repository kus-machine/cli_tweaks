<#
.SYNOPSIS
    cli_tweaks - Windows 11 installer (native PowerShell 7 + WezTerm).
.DESCRIPTION
    Mirrors the Ubuntu24 install.sh component model, using winget. Everything is
    per-user where winget allows it (no admin needed for tools/fonts). Existing
    files are backed up the first time they are replaced.

    Writes an install manifest to %LOCALAPPDATA%\cli_tweaks\install-manifest.json
    recording exactly what it installed / changed, so uninstall.ps1 can revert
    precisely and NEVER remove something that was already present beforehand.

    NOTE: run under Windows PowerShell 5.1 (to bootstrap pwsh7). Keep this file
    ASCII-only: 5.1 reads a no-BOM .ps1 as ANSI, turning non-ASCII punctuation
    into phantom string delimiters and breaking parsing.
.EXAMPLE
    ./install.ps1 -All
.EXAMPLE
    ./install.ps1 -Shell -Packages -Starship -Configs -WezTerm
.EXAMPLE
    ./install.ps1 -All -SetWindowsDefaultTerminalApp
.NOTES
    STATUS: the 2026-10-12 rewrite (WezTerm, tealdeer, lazy PSFzf, record-before-
    act) was built from a hand-tested trial setup but this script itself has NOT
    been run end-to-end yet - see docs/REMINDERS.md.
#>
[CmdletBinding()]
param(
    [switch]$All,
    [switch]$Shell,                        # install PowerShell 7 (pwsh)
    [switch]$Packages,                     # fzf fd eza zoxide ripgrep bat btop tealdeer + PSFzf
    [switch]$Fonts,                        # FiraCode Nerd Font (per-user)
    [switch]$Starship,                     # starship + shared starship.toml
    [switch]$Configs,                      # pwsh profile + keys.txt + lesskey + bat themes
    [switch]$WezTerm,                      # WezTerm (nightly) + shared/wezterm.lua
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
# Where the profile's data files live (keys.txt, lesskey).
$CliTweaksHome = Join-Path $HOME '.config\cli_tweaks'

$Packages_ = New-Object System.Collections.ArrayList
$Files_    = New-Object System.Collections.ArrayList
$Modules_  = New-Object System.Collections.ArrayList
$Fonts_    = New-Object System.Collections.ArrayList
$Dirs_     = New-Object System.Collections.ArrayList   # {path, preexisting}
$Wt_       = $null    # {path, backup, prevDefaultProfile, newDefaultProfile}
$WinTerm_  = $null    # {prevConsole, prevTerminal}
$BatCache_ = $false   # we ran `bat cache --build` (uninstall clears it)

# Seed from an existing manifest so re-runs accumulate and we never lose the
# ORIGINAL 'prev' values recorded on the first run.
if (Test-Path $ManifestPath) {
    try {
        $old = Get-Content $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($x in @($old.packages)) { if ($x) { [void]$Packages_.Add($x) } }
        foreach ($x in @($old.files))    { if ($x) { [void]$Files_.Add($x) } }
        foreach ($x in @($old.modules))  { if ($x) { [void]$Modules_.Add($x) } }
        foreach ($x in @($old.fonts))    { if ($x) { [void]$Fonts_.Add($x) } }
        foreach ($x in @($old.dirs))     { if ($x) { [void]$Dirs_.Add($x) } }
        if ($old.wt)                 { $Wt_ = $old.wt }
        if ($old.windowsTerminalApp) { $WinTerm_ = $old.windowsTerminalApp }
        if ($old.batCache)           { $BatCache_ = $true }
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

# Every Register-* keeps the FIRST record (CLAUDE.md rule 5a): on a re-run,
# what WE installed last time is present too, and must not be relabelled
# "preexisting" - uninstall would then never remove it.
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
# $Pre = the module dir already existed before we touched it. uninstall.ps1
# never removes a module flagged preexisting.
function Register-Module([string]$Name, [string]$Path, [bool]$Pre) {
    if (-not ($Modules_ | Where-Object { $_.name -eq $Name })) {
        [void]$Modules_.Add([pscustomobject]@{ name = $Name; path = $Path; preexisting = $Pre })
    }
}
# $Pre = the font file was already there before our first install (you had
# FiraCode Nerd Font already). uninstall.ps1 keeps such files and their
# registry values, even though the install refreshes them.
function Register-Font([string]$File, [string]$RegValue, [bool]$Pre) {
    if (-not ($Fonts_ | Where-Object { $_.file -eq $File })) {
        [void]$Fonts_.Add([pscustomobject]@{ file = $File; regValue = $RegValue; preexisting = $Pre })
    }
}
# A directory a tool creates for its own data (e.g. WezTerm's logs). Recorded
# BEFORE the tool first runs, so we know whether it existed already.
function Register-Dir([string]$Path) {
    if (-not ($Dirs_ | Where-Object { $_.path -eq $Path })) {
        [void]$Dirs_.Add([pscustomobject]@{ path = $Path; preexisting = (Test-Path $Path) })
    }
}
function Test-FileRegistered([string]$Path) {
    return [bool]($Files_ | Where-Object { $_.path -eq $Path })
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

# A tool winget installed a moment ago is usually NOT on this session's PATH
# yet. Look for it where winget puts it (same globs as the profile's PATH
# self-heal).
function Find-Tool([string]$Name, [string[]]$Globs) {
    $c = Get-Command $Name -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    foreach ($g in $Globs) {
        $f = Get-Item $g -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($f) { return $f.FullName }
    }
    return $null
}

# Run a native tool, ignore what it prints, report success. (Under
# ErrorActionPreference=Stop, Windows PowerShell 5.1 turns a native command's
# stderr into a terminating error - hence the local Continue.)
function Invoke-Quiet([string]$Exe, [string[]]$ArgList) {
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { & $Exe @ArgList 2>&1 | Out-Null; return ($LASTEXITCODE -eq 0) }
    catch { return $false }
    finally { $ErrorActionPreference = $old }
}

function Test-WingetInstalled([string]$Id) {
    $out = (winget list --id $Id --exact --accept-source-agreements 2>$null | Out-String)
    return ($out -match [regex]::Escape($Id))
}

# Record first, then install (rule 5a): if the install dies halfway, the
# manifest already says the package is ours. winget's exit code is not
# trusted on its own (it is non-zero for "already installed, no upgrade"), so
# a failure is judged by whether the package is listed afterwards.
function Winget-Install([string]$Id) {
    $pre = Test-WingetInstalled $Id
    Register-Package $Id $pre
    Write-Host ("  winget install {0}{1}" -f $Id, $(if ($pre) { '  (already present - will not be removed on uninstall)' } else { '' })) -ForegroundColor Cyan
    winget install --id $Id --exact --accept-source-agreements --accept-package-agreements --silent
    $rc = $LASTEXITCODE
    if (-not $pre -and -not (Test-WingetInstalled $Id)) {
        Write-Host "  WARNING: winget install $Id failed (exit $rc) - re-run this component later." -ForegroundColor Red
    }
}

# Capture the original ONCE (same rule as deploy_file on Ubuntu): if the
# manifest already knows this path, the file there is our own earlier deploy
# and the original is already safe in the recorded backup - just overwrite.
# Backing it up again on every run only piled up .bak copies of our config.
function Copy-Config([string]$Src, [string]$Dst) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Dst) | Out-Null
    if (-not (Test-FileRegistered $Dst)) {
        $bak = Backup-Move $Dst
        # Record the backup BEFORE copying: if the copy fails, the original is
        # already moved aside and the manifest must still know where it went.
        Register-File $Dst $bak
    }
    Copy-Item $Src $Dst -Force
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
        version             = 2
        updated             = (Get-Date -Format o)
        repoRoot            = $RepoRoot
        fontRegKey          = $FontRegKey
        packages            = @($Packages_)
        files               = @($Files_)
        modules             = @($Modules_)
        fonts               = @($Fonts_)
        dirs                = @($Dirs_)
        batCache            = $BatCache_
        wt                  = $Wt_
        windowsTerminalApp  = $WinTerm_
    }
    Write-Utf8NoBom $ManifestPath ($m | ConvertTo-Json -Depth 6)
    Write-Host "  manifest -> $ManifestPath" -ForegroundColor DarkGray
}

if (-not ($All -or $Shell -or $Packages -or $Fonts -or $Starship -or $Configs -or $WezTerm -or $SetDefaultTerminal -or $SetWindowsDefaultTerminalApp)) {
    Get-Help $PSCommandPath -Detailed
    exit 1
}

$PkgGlobs = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages"

# Everything below runs inside try/finally so the manifest is written even
# when a component throws ($ErrorActionPreference = Stop): files already
# moved aside and packages already installed must stay revertible, and a
# re-run must not mistake our own deployed config for your original.
try {
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
            'sharkdp.bat',             # bat (+ fzf previews)
            'aristocratos.btop4win',   # btop (command name on Windows is btop4win)
            'dbrgn.tealdeer'           # tldr (+ F1 in the profile)
        )
        foreach ($id in $ids) { Winget-Install $id }

        # tldr pages: tealdeer ships without them. Best-effort - a firewall that
        # blocks tldr.exe shows up as "os error 10013"; `tldr --update` later.
        # (winget puts tealdeer's tldr.exe in its package folder, not in Links)
        $tldr = Find-Tool 'tldr' @("$PkgGlobs\dbrgn.tealdeer*\tldr.exe", "$env:LOCALAPPDATA\Microsoft\WinGet\Links\tldr.exe")
        if ($tldr) {
            if (Invoke-Quiet $tldr @('--update')) { Write-Host "  tldr pages downloaded." -ForegroundColor Green }
            else { Write-Host "  tldr --update failed (network/firewall?) - run it later." -ForegroundColor DarkYellow }
        }

        # PSFzf (fzf keys for PSReadLine) must land in pwsh7's module scope
        # (Documents\PowerShell\Modules), NOT 5.1's. pwsh 7.4+ saves it with
        # Save-PSResource -TrustRepository, which trusts PSGallery for this one
        # call only - the old installer flipped PSGallery to Trusted for good.
        # The command goes in as -EncodedCommand: piping an inline -Command from
        # 5.1 into pwsh mangles quotes. posh-git is no longer installed: it was
        # the slowest part of the old 5 s start and is not used by the profile.
        $pwshPath = Get-PwshPath
        if ($pwshPath) {
            $pwshProfile = & $pwshPath -NoProfile -Command '$PROFILE.CurrentUserAllHosts'
            $modDir  = Join-Path (Split-Path $pwshProfile) 'Modules'
            $modPath = Join-Path $modDir 'PSFzf'
            $modPre  = Test-Path $modPath
            Register-Module 'PSFzf' $modPath $modPre
            if ($modPre) {
                Write-Host "  PSFzf already present in pwsh7 scope (will not be removed on uninstall)." -ForegroundColor DarkGray
            } else {
                Write-Host "  PSFzf module -> $modDir" -ForegroundColor Cyan
                New-Item -ItemType Directory -Force -Path $modDir | Out-Null
                $cmd = "Save-PSResource -Name PSFzf -Repository PSGallery -Path '$modDir' -TrustRepository -ErrorAction Stop"
                $enc = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($cmd))
                $ok  = Invoke-Quiet $pwshPath @('-NoProfile', '-NonInteractive', '-EncodedCommand', $enc)
                if (-not $ok -or -not (Test-Path $modPath)) {
                    Write-Host "  WARNING: PSFzf could not be saved (network?) - re-run -Packages later." -ForegroundColor Red
                }
            }
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

    # --- PowerShell profile + its data files + bat themes ----------------------
    if ($All -or $Configs) {
        Write-Host "== PowerShell profile ==" -ForegroundColor Yellow
        Copy-Config (Join-Path $PSScriptRoot 'Microsoft.PowerShell_profile.ps1') (Join-Path $HOME 'Documents\PowerShell\profile.ps1')
        Copy-Config (Join-Path $PSScriptRoot 'keys.txt') (Join-Path $CliTweaksHome 'keys.txt')
        Copy-Config (Join-Path $Shared 'lesskey')        (Join-Path $CliTweaksHome 'lesskey')

        # bat's Tokyo Night theme (Ubuntu: install-configs.sh). bat finds themes
        # in its config dir, %APPDATA%\bat\themes, after `bat cache --build`.
        $batThemes = Join-Path $env:APPDATA 'bat\themes'
        Get-ChildItem (Join-Path $Shared 'bat\themes') -Filter '*.tmTheme' | ForEach-Object {
            Copy-Config $_.FullName (Join-Path $batThemes $_.Name)
        }
        $bat = Find-Tool 'bat' @("$PkgGlobs\sharkdp.bat*\*\bat.exe")
        if ($bat) {
            $BatCache_ = $true                           # record before building
            if (Invoke-Quiet $bat @('cache', '--build')) { Write-Host "  bat theme cache built." -ForegroundColor Green }
            else { Write-Host "  bat cache --build failed - run it by hand." -ForegroundColor DarkYellow }
        } else {
            Write-Host "  bat not installed yet - themes copied; run 'bat cache --build' after -Packages." -ForegroundColor DarkYellow
        }
    }

    # --- WezTerm (terminal: tabs + panes, replaces Alacritty + tmux) ------------
    # Nightly, not stable: the last stable release is from 2024-02 and the
    # config was tested against nightly (which upstream recommends).
    #
    # NOT via winget: wez.wezterm.nightly pins the SHA256 of one nightly build,
    # but its URL always serves the newest one, so it fails with "Installer
    # hash does not match" (exit -1978335215) whenever upstream has built since
    # the manifest was published - i.e. nearly always. Instead the official
    # nightly zip goes to %LOCALAPPDATA%\Programs\WezTerm (per-user, no admin),
    # plus a Start menu shortcut. Re-running -WezTerm updates it to the newest
    # nightly. Both the folder and the shortcut are in the manifest.
    if ($All -or $WezTerm) {
        Write-Host "== WezTerm ==" -ForegroundColor Yellow
        # Its logs/sockets dir appears on first launch: note whether it existed.
        Register-Dir (Join-Path $HOME '.local\share\wezterm')
        $wzDir = Join-Path $env:LOCALAPPDATA 'Programs\WezTerm'
        Register-Dir $wzDir                                   # before creating it
        $wzEntry = $Dirs_ | Where-Object { $_.path -eq $wzDir } | Select-Object -First 1

        # WezTerm needs the Visual C++ 2015+ runtime. It is shared by many
        # programs, so we never install (and later remove) it ourselves.
        $vc = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64' -ErrorAction SilentlyContinue
        if (-not ($vc -and $vc.Installed -eq 1)) {
            Write-Host "  WARNING: the Visual C++ 2015+ x64 runtime seems missing - WezTerm will not start without it:" -ForegroundColor Red
            Write-Host "           winget install Microsoft.VCRedist.2015+.x64" -ForegroundColor Red
        }

        $running = Get-Process wezterm-gui, wezterm-mux-server -ErrorAction SilentlyContinue |
                   Where-Object { $_.Path -and $_.Path -like "$wzDir\*" }
        if ($wzEntry.preexisting) {
            Write-Host "  $wzDir existed before cli_tweaks - leaving it alone (not ours)." -ForegroundColor DarkYellow
        } elseif ($running) {
            Write-Host "  WezTerm is running from $wzDir - close it and re-run -WezTerm to update it." -ForegroundColor DarkYellow
        } else {
            $tmp = New-Item -ItemType Directory -Force -Path (Join-Path $env:TEMP "wezterm_$(Get-Random)")
            $zip = Join-Path $tmp 'wezterm.zip'
            Write-Host "  downloading the WezTerm nightly zip (~70 MB)" -ForegroundColor Cyan
            Invoke-WebRequest -Uri 'https://github.com/wezterm/wezterm/releases/download/nightly/WezTerm-windows-nightly.zip' -OutFile $zip -UseBasicParsing
            Expand-Archive $zip -DestinationPath $tmp -Force
            $gui = Get-ChildItem $tmp -Recurse -Filter 'wezterm-gui.exe' | Select-Object -First 1
            if (-not $gui) { throw "unexpected WezTerm zip layout in $tmp" }
            # Our own earlier copy (the manifest says the folder is ours): replace it.
            if (Test-Path $wzDir) { Remove-Item (Join-Path $wzDir '*') -Recurse -Force }
            New-Item -ItemType Directory -Force -Path $wzDir | Out-Null
            Copy-Item (Join-Path $gui.Directory.FullName '*') $wzDir -Recurse -Force
            Remove-Item $tmp -Recurse -Force
            Write-Host "  installed $wzDir" -ForegroundColor Green
        }

        # Start menu shortcut (search "WezTerm"; pin it from there).
        $lnk = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\WezTerm.lnk'
        if (-not (Test-FileRegistered $lnk)) {
            $bak = Backup-Move $lnk
            Register-File $lnk $bak                           # before writing
        }
        $sc = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk)
        $sc.TargetPath       = Join-Path $wzDir 'wezterm-gui.exe'
        $sc.WorkingDirectory = $HOME
        $sc.Description      = 'WezTerm (cli_tweaks)'
        $sc.Save()
        Write-Host "  installed $lnk" -ForegroundColor Green

        Copy-Config (Join-Path $Shared 'wezterm.lua') (Join-Path $HOME '.config\wezterm\wezterm.lua')
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
        # A font loaded into the session (AddFontResource, or simply in use) is
        # LOCKED: overwriting it fails with "being used by another process".
        # So: skip a file that is already identical, otherwise unload the old
        # one first; if it is still locked, warn and carry on with the rest.
        if (-not ('CliTweaks.Gdi' -as [type])) {
            Add-Type -Namespace CliTweaks -Name Gdi -MemberDefinition @'
[DllImport("gdi32.dll", CharSet = CharSet.Unicode)] public static extern int AddFontResource(string file);
[DllImport("gdi32.dll", CharSet = CharSet.Unicode)] public static extern int RemoveFontResource(string file);
'@
        }
        $locked = 0
        $replaced = 0
        Get-ChildItem $tmp -Filter '*.ttf' -Recurse | ForEach-Object {
            $dest = Join-Path $fontDir $_.Name
            $regVal = "$($_.BaseName) (TrueType)"
            Register-Font $dest $regVal (Test-Path $dest)   # before overwriting it
            $same = (Test-Path $dest) -and ((Get-FileHash $dest).Hash -eq (Get-FileHash $_.FullName).Hash)
            if (-not $same) {
                if (Test-Path $dest) { [void][CliTweaks.Gdi]::RemoveFontResource($dest); $replaced++ }
                try { Copy-Item $_.FullName $dest -Force -ErrorAction Stop }
                catch { $locked++; Write-Host "  in use, kept the old copy: $($_.Exception.Message)" -ForegroundColor DarkYellow }
            }
            New-ItemProperty -Path $FontRegKey -Name $regVal -Value $dest -PropertyType String -Force | Out-Null
            [void][CliTweaks.Gdi]::AddFontResource($dest)  # usable right away, no sign-out needed
        }
        Remove-Item $tmp -Recurse -Force
        if ($locked) {
            Write-Host "  FiraCode Nerd Font installed; $locked file(s) were in use and kept as they were (close apps / sign out, then -Fonts again to refresh them)." -ForegroundColor DarkYellow
        } else {
            Write-Host "  FiraCode Nerd Font installed (per-user)." -ForegroundColor Green
        }
        # Replacing a font file that this session already had loaded leaves
        # Windows' DirectWrite font cache pointing at the old file. WezTerm then
        # dies on start with "panic at ...dwrote...font_collection.rs" (seen
        # 2026-10-15) until the session is restarted.
        if ($replaced) {
            Write-Host "  NOTE: $replaced existing font file(s) were replaced - SIGN OUT and back in" -ForegroundColor Yellow
            Write-Host "        (or restart) before opening WezTerm, or it may crash on start." -ForegroundColor Yellow
        }
    }

    # --- Windows Terminal default profile -> PowerShell 7 ----------------------
    if ($All -or $SetDefaultTerminal) {
        Write-Host "== Windows Terminal default profile -> PowerShell 7 ==" -ForegroundColor Yellow
        if (Test-Path $WtSettings) {
            $json = Get-Content $WtSettings -Raw -Encoding UTF8 | ConvertFrom-Json
            $guid = Get-WtPwshProfileGuid $json
            if ($guid) {
                $prev = [string]$json.defaultProfile
                # Back up once: a re-run would only copy our own edit again.
                $bak  = $null
                if (-not $Wt_) { $bak = Backup-Copy $WtSettings }
                $raw  = Get-Content $WtSettings -Raw -Encoding UTF8
                if ($raw -match '"defaultProfile"\s*:') {
                    $new = [regex]::Replace($raw, '("defaultProfile"\s*:\s*)"[^"]*"', ('${1}"' + $guid + '"'))
                } else {
                    # Insert after the FIRST "{" only. This needs the INSTANCE
                    # Replace(input, replacement, count): the static
                    # [regex]::Replace has no count overload, so a trailing 1 there
                    # binds to RegexOptions (1 = IgnoreCase) and EVERY "{" in the
                    # file gets the key injected - a corrupted settings.json.
                    $new = ([regex]'\{').Replace($raw, ("{`r`n    " + '"defaultProfile": "' + $guid + '",'), 1)
                }
                # preserve the ORIGINAL prev value across re-runs; record before writing
                if (-not $Wt_) {
                    $Wt_ = [pscustomobject]@{ path = $WtSettings; backup = $bak; prevDefaultProfile = $prev; newDefaultProfile = $guid }
                } else {
                    $Wt_.newDefaultProfile = $guid
                }
                Write-Utf8NoBom $WtSettings $new
                Write-Host "  defaultProfile set to pwsh7 ($guid). Prev was $prev." -ForegroundColor Green
            } else {
                Write-Host "  Could not find a PowerShell 7 profile in Windows Terminal - skipped." -ForegroundColor DarkYellow
            }
        } else {
            Write-Host "  Windows Terminal settings.json not found - skipped." -ForegroundColor DarkYellow
        }
    }

    # --- Windows "Default terminal application" -> Windows Terminal (opt-in) ----
    # (WezTerm cannot be the system default terminal: only Windows Terminal
    # implements that delegation interface.)
    if ($SetWindowsDefaultTerminalApp) {
        Write-Host "== Windows default terminal application -> Windows Terminal ==" -ForegroundColor Yellow
        $startup = 'HKCU:\Console\%%Startup'
        $prevC = (Get-ItemProperty $startup -Name DelegationConsole  -ErrorAction SilentlyContinue).DelegationConsole
        $prevT = (Get-ItemProperty $startup -Name DelegationTerminal -ErrorAction SilentlyContinue).DelegationTerminal
        if (-not $WinTerm_) {
            $WinTerm_ = [pscustomobject]@{ prevConsole = [string]$prevC; prevTerminal = [string]$prevT }
        }
        New-Item -Path $startup -Force | Out-Null
        Set-ItemProperty -Path $startup -Name DelegationConsole  -Value $WtDelegationConsole
        Set-ItemProperty -Path $startup -Name DelegationTerminal -Value $WtDelegationTerminal
        Write-Host "  Set. Prev console=$prevC terminal=$prevT" -ForegroundColor Green
    }
} finally {
    Save-Manifest
}
Write-Host "`nDone." -ForegroundColor Green
exit 0   # avoid leaking a stray non-zero $LASTEXITCODE from winget subcommands
