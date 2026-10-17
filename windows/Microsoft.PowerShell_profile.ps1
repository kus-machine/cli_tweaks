# ============================================================================
# cli_tweaks -- PowerShell 7 profile  (Windows-native Ubuntu-like experience)
# ----------------------------------------------------------------------------
# Deployed by  windows/install.ps1 -Configs  to  $PROFILE.CurrentUserAllHosts
#   ~\Documents\PowerShell\profile.ps1        (PowerShell 7 / pwsh)
# together with its data files in  ~\.config\cli_tweaks\
#   keys.txt   the cheatsheet shown by `keys` and by WezTerm's Ctrl+B ?
#   lesskey    less's keys on the Ukrainian layout (from shared/lesskey)
# Every tool is wired only if present, so a partial install still loads clean.
#
# Startup time matters -- the first Windows setup took ~5 s to a prompt:
#   * PSFzf is imported lazily, on the first Ctrl+T / Ctrl+R / Alt+C (~0.5 s);
#   * `starship init` / `zoxide init` are cached as scripts in
#     %LOCALAPPDATA%\cli_tweaks\cache, rebuilt only when the tool changes;
#   * no posh-git (importing it cost about as much as everything else).
# Measured 2026-10-12: ~0.2 s for this file on top of pwsh's own ~0.2 s.
# To see where the time goes:   $env:CLI_TWEAKS_TIMING=1; pwsh
# ============================================================================

$ErrorActionPreference = 'Continue'

# ---------------------------------------------------------------------------
# UTF-8 on the console. pwsh reads THIS file as UTF-8 already, but the console
# the shell talks to still defaults to the legacy OEM code page -- so typing
# on the Ukrainian (or any non-Latin) layout echoes "?????" and Nerd Font /
# box-drawing glyphs come out wrong. Force UTF-8 both ways. Guarded: setting
# InputEncoding throws when input is redirected (e.g. piped). zoxide flips
# OutputEncoding per call and restores it, so this stays the steady state.
# ---------------------------------------------------------------------------
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
if (-not [Console]::IsOutputRedirected) {
    try {
        [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
        [Console]::InputEncoding  = [System.Text.UTF8Encoding]::new($false)
    } catch { }
}

# ---------------------------------------------------------------------------
# Startup timing (CLI_TWEAKS_TIMING=1 prints the table at the end)
# ---------------------------------------------------------------------------
$global:__ct_sw    = [Diagnostics.Stopwatch]::StartNew()
$global:__ct_marks = [System.Collections.Generic.List[object]]::new()
function global:__ct_mark([string]$Block) {
    $global:__ct_marks.Add([pscustomobject]@{ Block = $Block; Ms = [int]$global:__ct_sw.Elapsed.TotalMilliseconds })
    $global:__ct_sw.Restart()
}

$__ct_home  = "$HOME\.config\cli_tweaks"             # keys.txt, lesskey
$__ct_cache = "$env:LOCALAPPDATA\cli_tweaks\cache"   # cached init scripts

# ---------------------------------------------------------------------------
# PATH self-heal. winget appends a long per-tool dir to the user PATH; some
# launchers (and stale app environments, e.g. an already-open VS Code) drop the
# tail, so tools go missing. Re-add ours to THIS session if absent. Fast (only
# globs when a tool is actually missing) and version-independent.
# ---------------------------------------------------------------------------
$__pkgs = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages"
foreach ($__t in @(
    @{ c = 'fzf';      g = "$__pkgs\junegunn.fzf*\fzf.exe" },
    @{ c = 'eza';      g = "$__pkgs\eza-community.eza*\eza.exe" },
    @{ c = 'zoxide';   g = "$__pkgs\ajeetdsouza.zoxide*\zoxide.exe" },
    @{ c = 'fd';       g = "$__pkgs\sharkdp.fd*\*\fd.exe" },
    @{ c = 'rg';       g = "$__pkgs\BurntSushi.ripgrep*\*\rg.exe" },
    @{ c = 'bat';      g = "$__pkgs\sharkdp.bat*\*\bat.exe" },
    @{ c = 'btop4win'; g = "$__pkgs\aristocratos.btop4win*\btop4win\btop4win.exe" },
    @{ c = 'tldr';     g = "$__pkgs\dbrgn.tealdeer*\tldr.exe" },
    @{ c = 'starship'; g = "$env:ProgramFiles\starship\bin\starship.exe" }
)) {
    if (-not (Get-Command $__t.c -ErrorAction Ignore)) {
        $__exe = Get-Item $__t.g -ErrorAction Ignore | Select-Object -First 1
        if ($__exe) { $env:PATH = (Split-Path $__exe.FullName) + ';' + $env:PATH }
    }
}
Remove-Variable __pkgs, __t, __exe -ErrorAction Ignore

# __ct_cached_init <tool> <args>  ->  path of a .ps1 holding `<tool> <args>`'s
# output. `starship init` / `zoxide init` print a script that never changes
# until the tool itself is updated, yet running them costs a process start
# each (~300 ms together). So run them once, keep the script in
# %LOCALAPPDATA%\cli_tweaks\cache, and only regenerate it when the .exe is
# newer than the cached file. The caller dot-sources the path (at top level,
# so the definitions land globally). Delete that folder to force a rebuild.
#
# starship's script also runs `starship prompt --continuation` while loading
# (the "∙" shown on the 2nd line of a multi-line command) -- one more process,
# ~100 ms. Its answer depends only on starship.toml, so it is computed once
# here and written into the cached script as plain text. The cache is rebuilt
# when starship.exe OR starship.toml is newer than it.
function global:__ct_cached_init([string]$Tool, [string[]]$InitArgs) {
    $exe   = (Get-Command $Tool -CommandType Application | Select-Object -First 1).Source
    $cache = "$__ct_cache\$Tool-init.ps1"
    $conf  = if ($env:STARSHIP_CONFIG) { $env:STARSHIP_CONFIG } else { "$HOME\.config\starship.toml" }
    $deps  = @($exe) + @(if ($Tool -eq 'starship') { $conf })
    $stale = -not (Test-Path $cache)
    if (-not $stale) {
        $built = (Get-Item $cache).LastWriteTime
        $stale = @($deps | Where-Object { (Test-Path $_) -and (Get-Item $_).LastWriteTime -gt $built }).Count -gt 0
    }
    if ($stale) {
        New-Item -ItemType Directory -Force (Split-Path $cache) | Out-Null
        $script = & $exe @InitArgs | Out-String
        if ($Tool -eq 'starship') {
            $cont = (& $exe prompt --continuation | Out-String).TrimEnd("`r", "`n") -replace "'", "''"
            $script = $script -replace '(?s)Set-PSReadLineOption -ContinuationPrompt \(\s*Invoke-Native .*?"--continuation"\s*\)\s*\)',
                                       "Set-PSReadLineOption -ContinuationPrompt '$cont'"
        }
        $script | Set-Content $cache -Encoding utf8
    }
    $cache
}

# less (Git's: used by git log / git diff / `keys`): UTF-8 text, and its
# keys also on the Ukrainian layout (d = в, u = г, q = й ... see lesskey).
$env:LESSCHARSET = 'utf-8'
if (Test-Path "$__ct_home\lesskey") { $env:LESSKEYIN = "$__ct_home\lesskey" }

# Start in $HOME when launched from a system default dir (e.g. System32)
# rather than an intentional folder.
if ($PWD.Path -ieq "$env:WINDIR\System32" -or $PWD.Path -ieq $env:WINDIR) {
    Set-Location $HOME
}
__ct_mark 'env + PATH'

# ---------------------------------------------------------------------------
# PSReadLine: the Ubuntu/ble.sh feel
# ---------------------------------------------------------------------------
if (-not [Console]::IsOutputRedirected) {
    Set-PSReadLineOption -HistoryNoDuplicates -HistorySearchCursorMovesToEnd
    Set-PSReadLineOption -MaximumHistoryCount 1000000
    Set-PSReadLineOption -PredictionSource History        # grey suggestion
    Set-PSReadLineOption -Colors @{
        Default          = "`e[38;2;192;202;245m"   # #c0caf5 typed text
        Command          = "`e[38;2;122;162;247m"   # #7aa2f7 commands (blue)
        Parameter        = "`e[38;2;125;207;255m"   # #7dcfff -flags (cyan)
        String           = "`e[38;2;158;206;106m"   # #9ece6a strings (green)
        Variable         = "`e[38;2;224;175;104m"   # #e0af68 $vars (yellow)
        Operator         = "`e[38;2;137;221;255m"   # #89ddff | ; (light blue)
        Keyword          = "`e[38;2;187;154;247m"   # #bb9af7 if/foreach (magenta)
        Comment          = "`e[38;2;86;95;137m"     # #565f89
        Number           = "`e[38;2;255;158;100m"   # #ff9e64
        Error            = "`e[38;2;247;118;142m"   # #f7768e
        InlinePrediction = "`e[38;5;242m"           # grey 242, same as Ubuntu
    }
    Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Key Tab       -Function MenuComplete
    Set-PSReadLineKeyHandler -Key Ctrl+LeftArrow  -Function BackwardWord
    Set-PSReadLineKeyHandler -Key Ctrl+RightArrow -Function ForwardWord
    Set-PSReadLineKeyHandler -Key Ctrl+Backspace  -Function BackwardKillWord
    Set-PSReadLineKeyHandler -Key Ctrl+Delete     -Function KillWord
    Set-PSReadLineKeyHandler -Key RightArrow -Function ForwardChar   # accepts the suggestion at line end
    Set-PSReadLineKeyHandler -Key End        -Function EndOfLine
    # Ctrl+D: on an empty line exit the shell (closes the WezTerm pane), like
    # bash's EOF; on a non-empty line delete the char under the cursor.
    # PSReadLine's built-in DeleteCharOrExit does NOT reliably exit pwsh here
    # (its "exit" half is a no-op on Windows), so run `exit` explicitly.
    Set-PSReadLineKeyHandler -Key Ctrl+d -BriefDescription 'delete char or exit' -ScriptBlock {
        $l = $null; $c = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$l, [ref]$c)
        if ($l.Length -eq 0) {
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert('exit')
            [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
        } else {
            [Microsoft.PowerShell.PSConsoleReadLine]::DeleteChar()
        }
    }

    # Enter: run the line, then tell the terminal "command output starts here"
    # (OSC 133;C). With that, WezTerm knows exactly which text is the OUTPUT of
    # each command -> Ctrl+B y copies the last command's output, a 4x click
    # selects one command's whole output.
    Set-PSReadLineKeyHandler -Key Enter -BriefDescription 'AcceptLine+mark' -ScriptBlock {
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
        [Console]::Write("$([char]27)]133;C$([char]7)")
    }
}
__ct_mark 'PSReadLine'

# ---------------------------------------------------------------------------
# Aliases & functions  --  the Ubuntu .bash_aliases set
# ---------------------------------------------------------------------------
function global:c { Clear-Host }

# git. `gl` is PowerShell's built-in alias for Get-Location, and an alias
# beats a function -- remove it first or `gl` prints the current folder.
Remove-Item Alias:gl -Force -ErrorAction Ignore
function global:gs { git status @args }
function global:gd { git diff @args }
function global:gl { git log --graph @args }

# eza: coloured ls with icons. (No -h: for eza that is --header.)
if (Get-Command eza -ErrorAction Ignore) {
    function global:l   { eza -AlF --icons=always --group-directories-first @args }
    function global:la  { eza -AlF --icons=always --group-directories-first --total-size @args }
    function global:lss { eza -AlF --icons=always --group-directories-first --total-size --sort=size --reverse @args }
}

# tree [depth] [path] -- eza's tree, optional depth first; tree1..tree9 =
# "tree N". Without eza: Windows' own tree.com (it has no depth option).
function global:tree {
    $rest  = @($args)
    $level = @()
    if ($rest.Count -and "$($rest[0])" -match '^\d+$') {
        $level = @("--level=$($rest[0])")
        $rest  = @($rest | Select-Object -Skip 1)
    }
    if (Get-Command eza -ErrorAction Ignore) { eza --tree --icons=always @level @rest }
    else { tree.com @rest }
}
foreach ($__n in 1..9) {
    Set-Item "function:global:tree$__n" ([scriptblock]::Create("tree $__n @args"))
}

# fin <pattern> -- find by name from the CURRENT folder, hidden + ignored
# files included (fd's case-smart regex). Same as Ubuntu.
function global:fin {
    param([Parameter(Mandatory)][string]$Pattern)
    if (Get-Command fd -ErrorAction Ignore) { fd --hidden --no-ignore -- $Pattern }
    else { Get-ChildItem -Recurse -Force -Filter "*$Pattern*" -ErrorAction Ignore | ForEach-Object FullName }
}

# btop ships on Windows as btop4win.exe
if (Get-Command btop4win -ErrorAction Ignore) {
    function global:top  { btop4win @args }
    function global:htop { btop4win @args }
}

# bat: Tokyo Night, like Ubuntu. install.ps1 -Configs copies shared/bat/themes
# into bat's config dir (%APPDATA%\bat\themes) and runs `bat cache --build`.
# Another one:  $env:BAT_THEME = 'synthwave84'   (bat --list-themes)
if (-not $env:BAT_THEME) {
    $env:BAT_THEME = if (Test-Path "$env:APPDATA\bat\themes\tokyonight_night.tmTheme") { 'tokyonight_night' } else { 'ansi' }
}
__ct_mark 'aliases'

# ---------------------------------------------------------------------------
# fzf  --  Ctrl+T file · Ctrl+R history · Alt+C cd  (PSFzf), fd as backend
# ---------------------------------------------------------------------------
# Same exclude list as Ubuntu24/configs/.bashrc -- keep the two in sync.
if (Get-Command fd -ErrorAction Ignore) {
    $__ex = (@('.git', '.vscode', '.vscode-shared', '.cache', '.config', '.local') |
             ForEach-Object { "--exclude $_" }) -join ' '
    $env:FZF_DEFAULT_COMMAND = "fd --type f --hidden $__ex"     # fzf runs it itself
    $env:FZF_ALT_C_COMMAND   = "fd --type d --hidden $__ex"     # PSFzf runs it
}
# Previews (Ctrl+/ hides them). fzf runs these through cmd.exe on Windows,
# hence 2>NUL and ||: bat for a file, eza's tree when bat says "directory".
$__pv_file = 'bat --color=always --style=numbers --line-range=:300 {} 2>NUL || eza --tree --level=2 --icons=always --color=always {}'
$__pv_dir  = 'eza --tree --level=2 --icons=always --color=always {}'
$env:FZF_CTRL_T_OPTS = "--preview '$__pv_file' --preview-window 'right,60%,border-left' --bind 'ctrl-/:toggle-preview'"
$env:FZF_ALT_C_OPTS  = "--preview '$__pv_dir' --preview-window 'right,50%,border-left' --bind 'ctrl-/:toggle-preview'"
$env:FZF_CTRL_R_OPTS = "--preview 'echo {}' --preview-window 'down,4,wrap,border-top' --bind 'ctrl-/:toggle-preview'"

# PSFzf is loaded LAZILY: importing it costs ~0.5 s, the biggest single item
# of the old slow start. The three keys import it on their first press (that
# one press is ~0.5 s slower), then call its handlers directly.
# PSFzf throws on import if fzf is missing, so require it. Interactive only.
if ((Get-Command fzf -ErrorAction Ignore) -and -not [Console]::IsOutputRedirected) {
    function global:__ct_psfzf { if (-not (Get-Module PSFzf)) { Import-Module PSFzf -ErrorAction Stop } }
    Set-PSReadLineKeyHandler -Key Ctrl+t -BriefDescription 'fzf: pick files' -ScriptBlock {
        __ct_psfzf; Invoke-FzfPsReadlineHandlerProvider }
    Set-PSReadLineKeyHandler -Key Ctrl+r -BriefDescription 'fzf: search history' -ScriptBlock {
        __ct_psfzf; Invoke-FzfPsReadlineHandlerHistory }
    Set-PSReadLineKeyHandler -Key Alt+c  -BriefDescription 'fzf: cd into a folder' -ScriptBlock {
        __ct_psfzf; Invoke-FzfPsReadlineHandlerSetLocation }
}
__ct_mark 'fzf (PSFzf)'

# ---------------------------------------------------------------------------
# zoxide  --  `z <part of a path>` jumps to a folder you visited, `zi` picks
# one with fzf (interactive). The database is zoxide's default location,
# %LOCALAPPDATA%\zoxide.
# ---------------------------------------------------------------------------
if (Get-Command zoxide -ErrorAction Ignore) {
    . (__ct_cached_init 'zoxide' @('init', 'powershell'))
    # zoxide's generated hook records visited dirs by WRAPPING `prompt`. But the
    # starship block further down REPLACES `prompt` outright (so does the
    # fallback prompt), which silently kills the recording -- then the database
    # stays empty and `z foo` never matches. Record on every directory change
    # instead: LocationChangedAction is prompt-independent, so it survives
    # whoever owns the prompt. __zoxide_hook only adds when the path changed.
    $ExecutionContext.SessionState.InvokeCommand.LocationChangedAction = {
        if (Get-Command __zoxide_hook -ErrorAction Ignore) { __zoxide_hook }
    }
}
__ct_mark 'zoxide'

# ---------------------------------------------------------------------------
# F1  --  tldr examples for the command being typed (Ubuntu twin)
# ---------------------------------------------------------------------------
# "git commit -m" + F1 shows git-commit, "tar -x" + F1 shows tar. Wrapper
# words (sudo, gsudo, env, time ...) and VAR=value are skipped first. No tldr
# page: Get-Help for PowerShell commands. The typed line stays as it was.
# tldr = tealdeer (winget dbrgn.tealdeer); install.ps1 runs `tldr --update`
# once. Refresh the pages any time with  tldr --update  (needs the network --
# a firewall that blocks tldr.exe shows up as "os error 10013").
function global:cli_tweaks_f1([string]$Line) {
    $w = @(-split $Line)
    $i = 0
    while ($i -lt $w.Count) {
        if     ($w[$i] -match '^(sudo|gsudo|env|time|nohup|nice|command|exec|builtin)$') { }
        elseif ($w[$i] -like '-*' -and $i -gt 0)                                        { }
        elseif ($w[$i] -match '^[A-Za-z_][A-Za-z0-9_]*=')                               { }
        else { break }
        $i++
    }
    $cmd = if ($i -lt $w.Count) { $w[$i] } else { '' }
    $sub = if ($i + 1 -lt $w.Count) { $w[$i + 1] } else { '' }
    if (-not $cmd) { return }
    $cmd = $cmd -replace '\.exe$', ''
    if (Get-Command tldr -ErrorAction Ignore) {
        if ($sub -and $sub -notlike '-*') {
            $out = tldr --color always "$cmd-$sub" 2>$null
            if ($LASTEXITCODE -eq 0) { return $out }
        }
        $out = tldr --color always $cmd 2>$null
        if ($LASTEXITCODE -eq 0) { return $out }
    }
    if (Get-Command $cmd -CommandType Cmdlet, Function -ErrorAction Ignore) {
        return (Get-Help $cmd | Out-String)
    }
    "F1: no tldr page and no help for '$cmd'"
}
if (-not [Console]::IsOutputRedirected) {
    Set-PSReadLineKeyHandler -Key F1 -BriefDescription 'tldr for the command being typed' -ScriptBlock {
        $line = $null; $cursor = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
        $saved = $global:LASTEXITCODE
        $text  = cli_tweaks_f1 $line
        $global:LASTEXITCODE = $saved
        if ($text) {
            [Console]::WriteLine()
            $text | Out-Host
            [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
        }
    }
}
__ct_mark 'F1 (tldr)'

# ---------------------------------------------------------------------------
# alert  --  Windows notification when a long command finishes (Ubuntu twin)
# ---------------------------------------------------------------------------
#   sleep 5; alert          git pull; alert
# Title "done" or "failed", the command as the text. Sent to the terminal as
# OSC 777 -- WezTerm turns it into a Windows toast. $? must be read first.
function global:alert {
    $ok   = $?
    $code = $global:LASTEXITCODE
    $cmd  = ($MyInvocation.Line -replace '[;|&]\s*alert\s*$', '').Trim()
    $title = if ($ok) { 'done' } else { "failed$(if ($code) { " (exit $code)" })" }
    [Console]::Write("$([char]27)]777;notify;$title;$cmd$([char]7)")
}

# ---------------------------------------------------------------------------
# keys  --  the full cheatsheet (Ubuntu twin), read from
# ~\.config\cli_tweaks\keys.txt (repo: windows/keys.txt).
# Format: "# Heading", "keys<TAB>what it does", "<TAB>more text".
# Shown through Git's less like on Ubuntu (q closes); plain output without it.
#   keys          quits by itself when it fits the window (less -F)
#   keys -Stay    always waits for q  (WezTerm's Ctrl+B ? uses this)
# ---------------------------------------------------------------------------
function global:keys {
    param([switch]$Stay)
    $file = "$__ct_home\keys.txt"
    if (-not (Test-Path $file)) {
        Write-Host "keys: $file not found -- run windows/install.ps1 -Configs" -ForegroundColor DarkYellow
        return
    }
    $e = [char]27
    $head = "$e[38;2;122;162;247m"; $key = "$e[38;2;115;218;202m"
    $desc = "$e[38;2;169;177;214m"; $r = "$e[0m"
    $out = foreach ($line in Get-Content $file -Encoding UTF8) {
        if ($line -like '# *') {
            "$head$($line.Substring(2))$r"
        } elseif ($line -match "^([^\t]*)\t(.*)$") {
            "  $key$($Matches[1].PadRight(26))$r$desc$($Matches[2])$r"
        } else { $line }
    }
    $less = 'C:\Program Files\Git\usr\bin\less.exe'
    if (Test-Path $less) {
        $env:LESSCHARSET = 'utf-8'
        $flags = if ($Stay) { '-RX' } else { '-FRX' }
        $out | & $less $flags
    } else {
        $out
    }
}

# ---------------------------------------------------------------------------
# Startup banner  --  the Ubuntu cat + the most-forgettable keys
# ---------------------------------------------------------------------------
# Port of cli_tweaks_banner from Ubuntu24/configs/.bash_aliases. Only rows for
# things that work HERE. Shown in every new WezTerm window AND new tab; splits are started
# with CLI_TWEAKS_BANNER=0 (wezterm.lua), and the variable is set to 0 below
# after showing it, so `pwsh` typed inside pwsh stays quiet too.
# (Ubuntu shows it only once per tmux session -- new tmux tabs stay quiet.)
# Narrower than 79 columns: one line; narrower than 40: nothing.
function global:cli_tweaks_banner {
    $cols = try { $Host.UI.RawUI.WindowSize.Width } catch { 80 }
    $e = [char]27; $r = "$e[0m"
    $fg = { param($h) "$e[38;2;$([Convert]::ToInt32($h.Substring(0,2),16));$([Convert]::ToInt32($h.Substring(2,2),16));$([Convert]::ToInt32($h.Substring(4,2),16))m" }
    $cat_c  = & $fg 'bb9af7'   # magenta  the cat
    $title_c= & $fg 'ff9e64'   # orange   the title line
    $cmd_c  = & $fg '7aa2f7'   # blue     commands
    $arg_c  = & $fg '565f89'   # grey     ARGS you fill in
    $key_c  = & $fg 'bb9af7'   # magenta  keys to press
    $sep_c  = & $fg '565f89'   # grey     the · separators
    $desc_c = & $fg 'a9b1d6'   # soft fg  what it does
    $name_c = & $fg 'e0af68'   # yellow   the name, and the keys row

    if ($cols -lt 40) { return }
    if ($cols -lt 79) {
        Write-Host "$cat_c=^.^=$r ${title_c}cli_tweaks$r $desc_c· type$r ${cmd_c}keys$r ${desc_c}for every hotkey$r"
        return
    }

    # ASCII cat by hjw (Hayley Jane Wakenshaw); her "hjw" signature in the
    # box was replaced by the owner's name, credited here instead.
    $cat = @'
  ,-.       _,---._ __  / \
 /  )    .-'       `./ /   \
(  (   ,'            `/    /|
 \  `-"             \'\   / |
  `.              ,  \ \ /  |
   /`.          ,'-`----Y   |
  (            ;        |   '
  |  ,-.    ,-'  Andrii |  /
  |  | (   |    Pavliuk | /
  )  |  \  `.___________|/
  `--'   `--'
'@ -split "`r?`n"

    # Each word coloured by what it looks like (same rule as Ubuntu):
    # Ctrl+/Alt+/Shift+/arrows = key, ALLCAPS = argument, · = separator.
    $colour = {
        param($text)
        ($text -split '(\s+)' | ForEach-Object {
            if ($_ -match '^\s*$')                                  { $_ }
            elseif ($_ -eq '·')                                     { "$sep_c$_$r" }
            elseif ($_ -match '^(Ctrl|Alt|Shift)\+|^F\d+$|^[←↑→↓]$') { "$key_c$_$r" }
            elseif ($_ -cmatch '^[A-Z]+;?$')                        { "$arg_c$_$r" }
            else                                                    { "$cmd_c$_$r" }
        }) -join ''
    }

    # Rows 2..10 = "keys<TAB>what it does"; row 11, under the cat, = keys.
    # Same rows as Ubuntu where the tool exists here; tmux rows -> WezTerm keys.
    $rows = @(
        '', '',
        "l  la  lss`tlist · +sizes · by size",
        "tree3 DIR`ttree, 3 levels (tree1…9)",
        "fin TEXT`tfind by name, from here",
        "z PART`tjump to a visited folder",
        "gs  gd  gl`tgit status · diff · log",
        "Alt+T  Alt+\  Alt+-`tnew tab · split → · ↓",
        "Ctrl+T Ctrl+R Alt+C`tfzf: file · history · cd",
        "Ctrl+B y`tcopy last command output",
        "F1  ·  tldr CMD`texamples for a command",
        "keys  Ctrl+B ?`tall commands & hotkeys"
    )

    for ($i = 0; $i -lt $rows.Count; $i++) {
        $raw  = if ($i -lt $cat.Count) { $cat[$i] } else { '' }
        $line = $cat_c + ($raw -replace 'Andrii', "${name_c}Andrii$cat_c" -replace 'Pavliuk', "${name_c}Pavliuk$cat_c") + $r
        $pad  = ' ' * [Math]::Max(0, 31 - $raw.Length)
        if ($i -eq 0) {
            $line += $pad + "${title_c}cli_tweaks · github.com/kus-machine/cli_tweaks$r"
        } elseif ($rows[$i]) {
            $cmd, $desc = $rows[$i] -split "`t", 2
            $cpad = ' ' * [Math]::Max(0, 21 - $cmd.Length)
            if ($i -eq $rows.Count - 1) {   # keys row: all yellow
                $line += $pad + "$name_c$cmd$r$cpad$name_c$desc$r"
            } else {
                $line += $pad + (& $colour $cmd) + $cpad + "$desc_c$desc$r"
            }
        }
        Write-Host $line
    }
}

# ---------------------------------------------------------------------------
# Prompt  --  starship, plus the marks WezTerm needs
# ---------------------------------------------------------------------------
# The escape codes tell the terminal things it cannot see by itself:
#   OSC 7   current folder (WezTerm)          -> new tab / split opens HERE
#   OSC 9;9 current folder (Windows Terminal, same purpose)
#   OSC 133 where each prompt starts / the previous command ended
#           -> Alt+PgUp/PgDn jump between commands, Ctrl+B y, 4x click
# (OSC 133;C "output starts" is sent by the Enter key handler above.)
function global:__ct_marks([bool]$Ok) {
    $e = [char]27
    $p = $executionContext.SessionState.Path.CurrentLocation
    $s = "$e]133;D;$([int](-not $Ok))$e\" + "$e]133;A$e\"
    if ($p.Provider.Name -eq 'FileSystem') {
        $fs = $p.ProviderPath
        $s += "$e]9;9;`"$fs`"$e\" + "$e]7;file://$env:COMPUTERNAME/$($fs -replace '\\','/')$e\"
    }
    $s
}

# Fallback prompt in the starship layout, used when starship is missing.
function global:prompt {
    $ok = $?
    $e  = [char]27
    $fs = $executionContext.SessionState.Path.CurrentLocation.ProviderPath
    $short = $fs -replace [regex]::Escape($HOME), '~'
    $arrow = if ($ok) { "$e[1;32m▸$e[0m" } else { "$e[1;31m▸$e[0m" }
    (__ct_marks $ok) +
        "`n$e[1;32m$env:USERNAME$e[0m@$e[34m$env:COMPUTERNAME$e[0m $e[1;36m$short$e[0m`n" +
        "$arrow " + "$e]133;B$e\"
}

# starship (config: ~\.config\starship.toml from shared/starship.toml; its
# format must NOT end in a newline -- bash strips it, pwsh does not, and the
# cursor then sits one line BELOW the ▸).
# starship calls Invoke-Starship-PreCommand right before drawing the prompt,
# after it has saved the last command's status in $origDollarQuestion; we
# read that (PowerShell lets a called function see its caller's variables)
# so the 133;D mark carries the real success/failure.
if (Get-Command starship -ErrorAction Ignore) {
    . (__ct_cached_init 'starship' @('init', 'powershell', '--print-full-init'))
    function global:Invoke-Starship-PreCommand {
        $ok = if ($null -ne $origDollarQuestion) { [bool]$origDollarQuestion } else { $true }
        $host.UI.Write((__ct_marks $ok))
    }
}
__ct_mark 'starship'

# ---------------------------------------------------------------------------
# Show the banner -- new windows and new tabs, not splits (see above).
# Turn it off for good: setx CLI_TWEAKS_BANNER 0
# ---------------------------------------------------------------------------
if ($env:CLI_TWEAKS_BANNER -ne '0' -and -not [Console]::IsOutputRedirected) {
    cli_tweaks_banner
}
$env:CLI_TWEAKS_BANNER = '0'   # child shells (pwsh inside pwsh) stay quiet
__ct_mark 'banner'

if ($env:CLI_TWEAKS_TIMING -eq '1') {
    $__total = ($global:__ct_marks | Measure-Object Ms -Sum).Sum
    $global:__ct_marks | Format-Table -AutoSize | Out-Host
    Write-Host "profile total: $__total ms  (pwsh itself starts before this)"
}
Remove-Variable __n, __ex, __pv_file, __pv_dir, __total -ErrorAction Ignore
