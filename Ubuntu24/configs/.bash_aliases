alias gs='git status'

# some more ls aliases
# alias ll='ls -alF'
# alias la='ls -AlhF'
# alias l='ls -lAhF --group-directories-first  --color=auto'

# eza is colored ls with icons.
# No -h here: for eza that is --header (a column-title row), not ls's
# "human-readable" -- eza prints human-readable sizes by default.
alias l='eza -AlF --icons=always --group-directories-first'
alias la='eza -AlF --icons=always --group-directories-first  --total-size'
# other colors for size:
# alias l='eza -AlF --icons=always --group-directories-first --total-size --color-scale=all'
alias lss="eza -AlF --icons=always --group-directories-first --total-size --sort=size --reverse"

# ---------------------------------------------------------------------------
# tree  --  eza's tree view, with an optional depth in front
# ---------------------------------------------------------------------------
#   tree              whole tree of the current dir
#   tree 3            3 levels deep           (= eza --tree --level=3)
#   tree 3 /etc       3 levels of /etc
#   tree /etc -a      anything else goes straight to eza
#   tree1 .. tree9    shorthand: tree3 /etc == tree 3 /etc
#
# This shadows the classic tree(1) binary in interactive shells (the old
# `alias tree=` did the same); `command tree` still reaches it. Scripts are
# unaffected -- functions only live in this shell.
#
# History: this used to be a separate helper named `tr`, which shadowed
# coreutils tr(1) -- `echo foo | tr a-z A-Z` printed its usage, and the
# bash-completion scripts that call `tr` internally (gcc, java, update-rc.d,
# invoke-rc.d, add-apt-repository, xdg-settings) silently completed garbage.
# Never name a helper after a standard command.
#
# unalias first: an alias beats a function at call time, and the old
# `alias tree=` would also be expanded inside the definition below if this
# file is re-sourced in a shell that still has it.
unalias tree 2>/dev/null
tree() {
    if [[ ${1-} =~ ^[0-9]+$ ]]; then
        local depth=$1
        shift
        eza --tree --icons=always --level="$depth" "$@"
    else
        eza --tree --icons=always "$@"
    fi
}
tree1() { tree 1 "$@"; }
tree2() { tree 2 "$@"; }
tree3() { tree 3 "$@"; }
tree4() { tree 4 "$@"; }
tree5() { tree 5 "$@"; }
tree6() { tree 6 "$@"; }
tree7() { tree 7 "$@"; }
tree8() { tree 8 "$@"; }
tree9() { tree 9 "$@"; }


# fin <pattern> -- recursive find from the CURRENT directory, hidden and
# git-ignored files included. Same as `fin` on Windows: fd (apt: fdfind),
# falling back to find(1). The pattern is fd's: a case-smart regex, matched
# anywhere in the name. To search the whole disk, cd / first.
# (Was `sudo find /`: a password prompt, a crawl through /proc, /sys and every
# mount, and with no argument it dumped the entire filesystem.)
fin() {
    if [[ $# -ne 1 ]]; then
        echo "Usage: fin <pattern>   (searches from the current directory)"
        return 1
    fi
    if command -v fdfind >/dev/null 2>&1; then
        fdfind --hidden --no-ignore -- "$1"
    else
        find . -iname "*$1*" 2>/dev/null
    fi
}

alias top="btop"
alias htop="btop"

# tmux aliases
alias t="tmux"
alias tls="tmux ls"
ta() {
    session=$(tmux ls -F "#{session_name}" 2>/dev/null | head -n 1)
    if [ -z "$session" ]; then
        echo "No tmux sessions found"
    else
        tmux attach -t "$session"
    fi
}
# tk: inside tmux, kill the current session. Outside tmux the only target is
# the whole server, i.e. EVERY session -- so list them and ask first.
tk() {
    if [ -n "$TMUX" ]; then
        tmux kill-session -t "$(tmux display-message -p '#S')"
    else
        tmux ls 2>/dev/null || { echo "No tmux sessions found"; return 0; }
        local reply
        printf 'Kill ALL tmux sessions above? [y/N] '
        read -r reply
        if [[ $reply == [yY]* ]]; then
            tmux kill-server
        fi
    fi
}
tn() {
    tmux new -s "s$(date +%H%M%S)"
}


# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias dir='dir --color=auto'
    alias vdir='vdir --color=auto'
    alias c="clear"

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'
