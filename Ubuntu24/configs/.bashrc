# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac


# ---------------------------------------------------------------------------
# ble.sh  --  fish-style inline autosuggestions (grey text after the cursor)
# ---------------------------------------------------------------------------
# Plain readline cannot show a suggestion while you type. ble.sh (Bash Line
# Editor) replaces bash's line editor and adds it -- the same feel as
# zsh-autosuggestions on macOS and PSReadLine's InlinePrediction on Windows.
#
# Installed by  ./install.sh --blesh  into ~/.local/share/blesh (there is no
# apt package for it on Ubuntu 24.04). Absent = this block is skipped and the
# shell behaves exactly as before.
#
# Load order matters and is deliberately split in two:
#   * source ... --attach=none  goes HERE, first, so everything below
#     (bash-completion, fzf, starship, our `bind` lines) is registered through
#     ble.sh's emulation layer instead of raw readline. starship in particular
#     checks $BLE_VERSION at init time to hook itself in the ble.sh way.
#   * ble-attach goes at the very END of this file. In between, ble.sh is
#     loaded but not yet driving the terminal.
# Do not collapse the two halves into one.
#
# ble.sh's own settings -- how eager the suggestion is, and the Tokyo Night
# palette for the line you type -- live in ~/.blerc, which ble.sh sources by
# itself. Keep bleopt/ble-face lines out of this file and edit ~/.blerc instead
# (repo: Ubuntu24/configs/.blerc).
if [[ -s "$HOME/.local/share/blesh/ble.sh" ]]; then
    source "$HOME/.local/share/blesh/ble.sh" --attach=none
fi

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth:erasedups

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000000
HISTFILESIZE=2000000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
#force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
    # We have color support; assume it's compliant with Ecma-48
    # (ISO/IEC-6429). (Lack of such support is extremely rare, and such
    # a case would tend to support setf rather than setaf.)
    color_prompt=yes
    else
    color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac


# colored GCC warnings and errors
#export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'


# ---------------------------------------------------------------------------
# Programmable completion  --  MUST be loaded BEFORE the fzf block below.
# ---------------------------------------------------------------------------
# Why the order matters (this bit me: Tab worked in tmux but not in Alacritty):
#
#   fzf's completion.bash hijacks the completion of ~35 commands (git, ls, cp,
#   rm, cd, ssh, kill, export, ...) with _fzf_path_completion. When you do NOT
#   type the `**` trigger, it is supposed to hand the request back to the real
#   completion via _fzf_handle_dynamic_completion. That fallback only works if
#   bash-completion's `_completion_loader` already existed when completion.bash
#   was sourced -- it records that in `_fzf_completion_loader`.
#
#   Source fzf first and that flag stays empty, so the fallback silently does
#   nothing: `git stat<Tab>` just beeps. tmux hid the bug because tmux starts a
#   *login* shell, and /etc/profile.d/bash_completion.sh loads bash-completion
#   before ~/.bashrc ever runs. Alacritty/GNOME Terminal start a *non-login*
#   shell, so ~/.bashrc is the only chance to get the order right.
#
# Keep this block above the fzf block. Do not "tidy" it back down.
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi


# fzf backend configuration: skip VCS/editor/cache dirs, and also ~/.config and
# ~/.local so Ctrl+T from $HOME is not drowned in app state. The same list is
# used by the Windows profile -- keep the two in sync.
# Only when fd is installed (apt names it fdfind): pointing fzf at a missing
# command would leave Ctrl+T / Alt+C with an empty list instead of fzf's own
# built-in file walker.
if command -v fdfind >/dev/null 2>&1; then
    EXCLUDES=(.git .vscode .vscode-shared .cache .config .local)
    FDFIND_EXCLUDES=""
    for dir in "${EXCLUDES[@]}"; do
        FDFIND_EXCLUDES+=" --exclude $dir"
    done
    unset dir

    export FZF_DEFAULT_COMMAND="fdfind --type f --hidden$FDFIND_EXCLUDES"
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND="fdfind --type d --hidden$FDFIND_EXCLUDES"
fi

# fzf previews, shown on the side of each picker:
#   Ctrl+T  the file with syntax colours + line numbers (bat), or a folder's tree
#   Alt+C   the tree of the folder under the cursor (eza, 2 levels)
#   Ctrl+R  the whole command, wrapped -- long ones are cut off in the list
#   Ctrl+/  inside any of them hides / shows the preview
# bat's "ansi" theme draws with the terminal's own 16 colours, i.e. Tokyo Night
# from alacritty.toml; `export BAT_THEME=TwoDark` (Nord, Dracula, ...) in
# ~/.bashrc.local picks another one for previews and `bat` alike. Without bat
# or eza the previews fall back to head / ls.
__fzf_bat=$(command -v batcat || command -v bat)     # Ubuntu calls it batcat
if [[ $__fzf_bat ]]; then
    export BAT_THEME=${BAT_THEME:-ansi}
    __fzf_file="$__fzf_bat --color=always --style=numbers --line-range=:300 {}"
else
    __fzf_file='head -300 {}'
fi
if command -v eza >/dev/null 2>&1; then
    __fzf_dir='eza --tree --level=2 --icons=always --color=always {} | head -200'
else
    __fzf_dir='ls -la {}'
fi
export FZF_CTRL_T_OPTS="--preview '[[ -d {} ]] && $__fzf_dir || $__fzf_file' --preview-window 'right,60%,border-left' --bind 'ctrl-/:toggle-preview'"
export FZF_ALT_C_OPTS="--preview '$__fzf_dir' --preview-window 'right,50%,border-left' --bind 'ctrl-/:toggle-preview'"
# {2..}: the history line without its leading number
export FZF_CTRL_R_OPTS="--preview 'echo {2..}' --preview-window 'down,4,wrap,border-top' --bind 'ctrl-/:toggle-preview'"
unset __fzf_bat __fzf_file __fzf_dir

if [[ ${BLE_VERSION-} ]]; then
    # ble.sh ships its own fzf integration and it must be used instead of the
    # stock scripts: those bind Ctrl+R/Ctrl+T through readline, which ble.sh no
    # longer uses, and fzf's Ctrl+R would fight ble.sh over the history widget.
    # The modules locate Ubuntu's /usr/share/doc/fzf/examples themselves.
    if command -v fzf >/dev/null 2>&1; then
        ble-import -d integration/fzf-completion
        ble-import -d integration/fzf-key-bindings
    fi
else
    # Enable fzf keybindings (Ubuntu 24.04 apt installation)
    if [ -f /usr/share/doc/fzf/examples/key-bindings.bash ]; then
        source /usr/share/doc/fzf/examples/key-bindings.bash
    fi

    # Enable fzf completion (Debian/Ubuntu specific path)
    if [ -f /usr/share/bash-completion/completions/fzf ]; then
        source /usr/share/bash-completion/completions/fzf
    fi
fi


if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"

# Starship bash wrapper. Guarded: `./install.sh --configs` without --starship
# must not greet every new shell with "starship: command not found" -- the
# stock PS1 set further up stays in effect instead.
if command -v starship >/dev/null 2>&1; then
    eval "$(starship init bash)"
fi

# zoxide: `z <part of a path>` jumps to the best-matching folder you have
# visited, `zi` picks one with fzf. Its init hooks PROMPT_COMMAND to learn the
# folders you cd into, so like everything else here it must come before
# ble-attach (zoxide's docs say "at the end of .bashrc" -- this is as late as
# that may go). Guarded: the package comes with ./install.sh --packages.
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init bash)"
fi


# Use ls colors for completion
export LS_COLORS="$LS_COLORS"
export GREP_COLORS=""

# Force Bash to use colored completion
bind "set colored-stats on"
bind "set colored-completion-prefix on"
bind "set mark-symlinked-directories on"


# Enable history search with UP/DOWN
#
# Only when ble.sh is NOT running. Its readline emulation would accept these
# and turn them into an interactive nsearch session with a
# "(nsearch#1: << !504 >>)" status line instead of readline's instant
# replace-the-line. ~/.blerc binds the arrows properly for that case, and a
# `bind` here would silently overwrite it.
if [[ ! ${BLE_VERSION-} ]]; then
    bind '"\e[A": history-search-backward'
    bind '"\e[B": history-search-forward'

    # Word deletion, mirroring the ble.sh bindings in ~/.blerc. Ctrl+Backspace
    # arrives as the byte 0x08 (^H) -- Alacritty/GNOME Terminal/tmux send
    # nothing fancier -- so Ctrl+H deletes a word too; accepted. Alt+Backspace
    # (\e\x7f) is already backward-kill-word by readline default. Ctrl+Del has
    # no default binding in readline at all, hence the \e[3;5~ line.
    bind '"\C-h": backward-kill-word'
    bind '"\e[3;5~": kill-word'
fi


# ---------------------------------------------------------------------------
# Machine-local additions  --  ~/.bashrc.local
# ---------------------------------------------------------------------------
# ./install.sh --configs replaces this whole file, so anything appended to it
# by hand or by other installers (nvm, conda, cargo, sdkman, ...) is lost on the
# next deploy -- and would land AFTER ble-attach anyway, which must stay last.
# Put such lines in ~/.bashrc.local instead: it is never deployed, captured or
# removed by cli_tweaks, and it is sourced here, after everything above (so it
# can override any of it) but still before ble.sh attaches.
if [ -f "$HOME/.bashrc.local" ]; then
    . "$HOME/.bashrc.local"
fi


# ---------------------------------------------------------------------------
# Startup banner  (the cat + key macros; `keys` prints the full cheatsheet)
# ---------------------------------------------------------------------------
# Once per new TERMINAL, not once per shell:
#   * inside tmux, only in the very first pane of a new session -- not on
#     Ctrl+B | / Ctrl+B - splits or Ctrl+B c windows;
#   * outside tmux, only in a top-level shell (SHLVL 1), so typing `bash`
#     inside bash stays quiet;
#   * never when output is not a terminal.
# After ~/.bashrc.local, so `CLI_TWEAKS_BANNER=0` there switches it off.
# Defined in ~/.bash_aliases.
if [[ ${CLI_TWEAKS_BANNER-1} != 0 && -t 1 ]] && declare -F cli_tweaks_banner >/dev/null; then
    if [[ -n ${TMUX-} ]]; then
        [[ $(tmux display -p -t "${TMUX_PANE-}" '#{session_windows}#{window_panes}' 2>/dev/null) == 11 ]] &&
            cli_tweaks_banner
    elif [[ ${SHLVL:-1} -le 1 ]]; then
        cli_tweaks_banner
    fi
fi


# ---------------------------------------------------------------------------
# ble.sh, part two: attach. MUST be the last thing in this file -- see the
# block at the top. Nothing that binds keys or touches PROMPT_COMMAND should
# come after it.
# ---------------------------------------------------------------------------
if [[ ${BLE_VERSION-} ]]; then
    ble-attach
fi
