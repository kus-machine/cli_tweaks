# ============================================================================
# cli_tweaks — PowerShell 7 profile  (Windows-native Ubuntu-like experience)
# ----------------------------------------------------------------------------
# Deployed to:  $PROFILE.CurrentUserAllHosts
#   ~\Documents\PowerShell\profile.ps1        (PowerShell 7 / pwsh)
# Every tool is wired only if present, so a partial install still loads clean.
# ============================================================================

$ErrorActionPreference = 'Continue'

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
}

# ---------------------------------------------------------------------------
# fzf fuzzy search  (Ctrl+T files, Ctrl+R history, Alt+C cd) with fd backend
# ---------------------------------------------------------------------------
if (Get-Command fd -ErrorAction SilentlyContinue) {
    $env:FZF_DEFAULT_COMMAND = 'fd --type f --hidden --exclude .git --exclude .cache'
    $env:FZF_CTRL_T_COMMAND  = $env:FZF_DEFAULT_COMMAND
    $env:FZF_ALT_C_COMMAND   = 'fd --type d --hidden --exclude .git --exclude .cache'
}
if (Get-Module -ListAvailable PSFzf) {
    Import-Module PSFzf
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
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

if (Get-Command eza -ErrorAction SilentlyContinue) {
    function l   { eza -AlhF --icons=always --group-directories-first @args }
    function la  { eza -AlhF --icons=always --group-directories-first --total-size @args }
    function lss { eza -AlhF --icons=always --group-directories-first --total-size --sort=size --reverse @args }
    function tree { eza --tree --icons=always @args }
    # tr [depth] [path]  — like `tree -L`
    function tr {
        param([string]$a, [string]$b)
        if (-not $a)                 { eza --tree --icons=always }
        elseif ($a -match '^\d+$' -and $b) { eza --tree --icons=always --level=$a $b }
        elseif ($a -match '^\d+$')   { eza --tree --icons=always --level=$a }
        else                         { eza --tree --icons=always $a }
    }
}

function c  { Clear-Host }
function gs { git status @args }
function gd { git diff @args }
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
# Starship prompt (must be near the end)
# ---------------------------------------------------------------------------
if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (& starship init powershell)
}
