alias gs='git status'

# some more ls aliases
# alias ll='ls -alF'
# alias la='ls -AlhF'
# alias l='ls -lAhF --group-directories-first  --color=auto'

# eza is colored ls with icons
alias ls='eza --icons=always --group-directories-first'
alias l='eza -AlhF --icons=always --group-directories-first'
alias tree='eza --tree --icons=always'


# tr 5 means tree -L 5
tr() {
    if [ $# -eq 0 ]; then
        tree
    elif [[ $1 =~ ^[0-9]+$ ]]; then
        tree -L "$1"
    else
        echo "Usage: tr [depth]"
        return 1
    fi
}


# powerful easy find across every possible folder
fin() {
    sudo find / -iname "*$1*" 2>/dev/null
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
tk() {
    if [ -n "$TMUX" ]; then
        tmux kill-session -t "$(tmux display-message -p '#S')"
    else
        tmux kill-server
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
