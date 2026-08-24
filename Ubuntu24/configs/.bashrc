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


# fzf backend configuration (ignoring .git, .vscode, and .cache)
EXCLUDES=(.git .vscode .vscode-shared .cache .config .local)
FDFIND_EXCLUDES=""
for dir in "${EXCLUDES[@]}"; do
    FDFIND_EXCLUDES+=" --exclude $dir"
done

export FZF_DEFAULT_COMMAND="fdfind --type f --hidden$FDFIND_EXCLUDES"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="fdfind --type d --hidden$FDFIND_EXCLUDES"

if [[ ${BLE_VERSION-} ]]; then
    # ble.sh ships its own fzf integration and it must be used instead of the
    # stock scripts: those bind Ctrl+R/Ctrl+T through readline, which ble.sh no
    # longer uses, and fzf's Ctrl+R would fight ble.sh over the history widget.
    # The modules locate Ubuntu's /usr/share/doc/fzf/examples themselves.
    ble-import -d integration/fzf-completion
    ble-import -d integration/fzf-key-bindings
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

# Starship bash wrapper
eval "$(starship init bash)"


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
# ble.sh, part two: attach. MUST be the last thing in this file -- see the
# block at the top. Nothing that binds keys or touches PROMPT_COMMAND should
# come after it.
# ---------------------------------------------------------------------------
if [[ ${BLE_VERSION-} ]]; then
    ble-attach
fi
