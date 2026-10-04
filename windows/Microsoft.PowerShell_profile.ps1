# ============================================================================
# cli_tweaks — PowerShell 7 profile  (Windows-native Ubuntu-like experience)
# ----------------------------------------------------------------------------
# Deployed to:  $PROFILE.CurrentUserAllHosts
#   ~\Documents\PowerShell\profile.ps1        (PowerShell 7 / pwsh)
# Every tool is wired only if present, so a partial install still loads clean.
# ============================================================================

$ErrorActionPreference = 'Continue'

# Start in $HOME when launched from a system default dir (e.g. System32) rather
# than an intentional folder, so "Open in Alacritty here" / cd-then-launch still
# land where you meant.
if ($PWD.Path -ieq "$env:WINDIR\System32" -or $PWD.Path -ieq $env:WINDIR) {
    Set-Location $HOME
}

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
    @{ c = 'btop4win'; g = "$__pkgs\aristocratos.btop4win*\btop4win\btop4win.exe" }
)) {
    if (-not (Get-Command $__t.c -ErrorAction Ignore)) {
        $__exe = Get-Item $__t.g -ErrorAction Ignore | Select-Object -First 1
        if ($__exe) { $env:PATH = (Split-Path $__exe.FullName) + ';' + $env:PATH }
    }
}
Remove-Variable __pkgs, __t, __exe -ErrorAction Ignore

# ---------------------------------------------------------------------------
# History + PSReadLine (bash-like editing & history search)
# ---------------------------------------------------------------------------
# Only wire the interactive editor when we have a real terminal — guards
# against errors when the profile loads in a redirected / piped session.
if ((Get-Module -ListAvailable PSReadLine) -and -not [Console]::IsOutputRedirected) {
    Import-Module PSReadLine
    Set-PSReadLineOption -HistoryNoDuplicates -HistorySearchCursorMovesToEnd
    Set-PSReadLineOption -PredictionSource History
    Set-PSReadLineOption -MaximumHistoryCount 1000000
    # Typed text = bright white; the inline history suggestion = dim grey, so the
    # two are clearly distinct. (256-colour codes; tweak 255/242 to taste.)
    Set-PSReadLineOption -Colors @{
        Default          = "`e[38;5;255m"
        Command          = "`e[38;5;255m"
        InlinePrediction = "`e[38;5;242m"
    }
    # UP/DOWN search history by what you've already typed (matches Ubuntu bind)
    Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    # Alt+arrow / Ctrl+arrow word jumps
    Set-PSReadLineKeyHandler -Key Ctrl+LeftArrow  -Function BackwardWord
    Set-PSReadLineKeyHandler -Key Ctrl+RightArrow -Function ForwardWord
    # Word deletion, matching Linux (ble.sh) and macOS (zsh). These are
    # PSReadLine's Windows-mode defaults; pinned explicitly so the cross-shell
    # parity survives a PSReadLine edit-mode change.
    Set-PSReadLineKeyHandler -Key Ctrl+Backspace -Function BackwardKillWord
    Set-PSReadLineKeyHandler -Key Ctrl+Delete    -Function KillWord
    # Bash-like Tab: show a navigable list of candidates, auto-complete when
    # there is only one match (instead of cycling through them one by one).
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
}

# ---------------------------------------------------------------------------
# fzf fuzzy search  (Ctrl+T files, Ctrl+R history, Alt+C cd) with fd backend
# ---------------------------------------------------------------------------
# Same exclude list as Ubuntu's ~/.bashrc - keep the two in sync.
if (Get-Command fd -ErrorAction SilentlyContinue) {
    $__fzfExcludes = (@('.git', '.vscode', '.vscode-shared', '.cache', '.config', '.local') |
        ForEach-Object { "--exclude $_" }) -join ' '
    $env:FZF_DEFAULT_COMMAND = "fd --type f --hidden $__fzfExcludes"
    $env:FZF_CTRL_T_COMMAND  = $env:FZF_DEFAULT_COMMAND
    $env:FZF_ALT_C_COMMAND   = "fd --type d --hidden $__fzfExcludes"
    Remove-Variable __fzfExcludes
}
# PSFzf's Import-Module throws if the fzf binary isn't on PATH, so require it.
if ((Get-Command fzf -ErrorAction SilentlyContinue) -and (Get-Module -ListAvailable PSFzf)) {
    Import-Module PSFzf
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
    # Alt+C = fuzzy cd. The two chords above do not include it, so bind it by
    # hand (works on every PSFzf version), then redraw so the prompt shows the
    # new directory. NOTE: added from Linux - still needs a check on Windows.
    if (Get-Command Invoke-FuzzySetLocation -ErrorAction SilentlyContinue) {
        Set-PSReadLineKeyHandler -Key Alt+c -ScriptBlock {
            Invoke-FuzzySetLocation
            [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
        }
    }
}

# ---------------------------------------------------------------------------
# zoxide  (smarter cd — `z <partial>`)
# ---------------------------------------------------------------------------
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}

# ---------------------------------------------------------------------------
# Aliases & functions — mirror of the Ubuntu .bash_aliases
# ---------------------------------------------------------------------------
Remove-Item Alias:l    -ErrorAction SilentlyContinue  # PS ships some of these
Remove-Item Alias:tree -ErrorAction SilentlyContinue

# No -h in the eza flags: for eza that is --header (a column-title row), not
# ls's "human-readable" - eza sizes are human-readable already.
if (Get-Command eza -ErrorAction SilentlyContinue) {
    function l   { eza -AlF --icons=always --group-directories-first @args }
    function la  { eza -AlF --icons=always --group-directories-first --total-size @args }
    function lss { eza -AlF --icons=always --group-directories-first --total-size --sort=size --reverse @args }
    # tree [depth] [args...] — eza tree; a leading number is the depth:
    #   tree 3 C:\src  ==  eza --tree --level=3 C:\src
    # tree1 .. tree9 are shorthands: tree3 C:\src == tree 3 C:\src.
    # Same as Ubuntu. Shadows Windows' tree.com (`tree.com` still reaches it).
    function tree {
        if ($args.Count -and "$($args[0])" -match '^\d+$') {
            $rest = @($args | Select-Object -Skip 1)
            eza --tree --icons=always "--level=$($args[0])" @rest
        } else {
            eza --tree --icons=always @args
        }
    }
    function tree1 { tree 1 @args }
    function tree2 { tree 2 @args }
    function tree3 { tree 3 @args }
    function tree4 { tree 4 @args }
    function tree5 { tree 5 @args }
    function tree6 { tree 6 @args }
    function tree7 { tree 7 @args }
    function tree8 { tree 8 @args }
    function tree9 { tree 9 @args }
}

function c  { Clear-Host }
function gs { git status @args }
function gd { git diff @args }
# `gl` is a built-in alias for Get-Location, and PowerShell resolves aliases
# BEFORE functions -- without this line `gl` prints the current directory and
# the function below is never reached. -Force: built-in aliases can be ReadOnly.
Remove-Item Alias:gl -Force -ErrorAction SilentlyContinue
function gl { git log --graph @args }

# fin <pattern> — fuzzy/recursive find from current dir (fd, fallback to native)
function fin {
    param([Parameter(Mandatory)][string]$pattern)
    if (Get-Command fd -ErrorAction SilentlyContinue) { fd --hidden --no-ignore $pattern }
    else { Get-ChildItem -Recurse -Force -Filter "*$pattern*" -ErrorAction SilentlyContinue | Select-Object -Expand FullName }
}

# btop ships on Windows as btop4win.exe (winget: aristocratos.btop4win)
$btop = (Get-Command btop -ErrorAction SilentlyContinue) ?? (Get-Command btop4win -ErrorAction SilentlyContinue)
if ($btop) {
    function top  { & $btop.Source @args }
    function htop { & $btop.Source @args }
}

# ---------------------------------------------------------------------------
# posh-git: git tab-completion (subcommands, params, branches, remotes).
# Imported before starship so starship still owns the prompt.
# ---------------------------------------------------------------------------
if (Get-Module -ListAvailable posh-git) {
    Import-Module posh-git
}

# ---------------------------------------------------------------------------
# Starship prompt (must be near the end)
# ---------------------------------------------------------------------------
if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (& starship init powershell)
}
