#PROMPT="%n@%m %d %# "
# fancy text in terminal before % : username green, full current dir blue
PS1="%F{green}%n@%m%f:%F{cyan}%~%f %# "

export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"
export EDITOR=nano

# better history
HISTSIZE=100000
SAVEHIST=100000
HISTFILE=~/.zsh_history
setopt HIST_IGNORE_DUPS HIST_IGNORE_ALL_DUPS HIST_IGNORE_SPACE
setopt SHARE_HISTORY
setopt INC_APPEND_HISTORY
setopt EXTENDED_HISTORY
# Make history shared across all sessions:
setopt APPEND_HISTORY
setopt HIST_FCNTL_LOCK

# -------------------------
# Plugins
# -------------------------
# Autosuggestions
source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh

# Syntax highlighting (must be last plugin!)
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# FZF
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh


# -------------------------
# Keybindings
# -------------------------
bindkey "^[b" backward-word      # Alt+B = jump back one word
bindkey "^[f" forward-word       # Alt+F = jump forward one word
bindkey "^[d" kill-word          # Alt+D = delete next word

# Search history based on current input
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward

# Make Zsh treat / as a word separator (like bash)
WORDCHARS='*?_[]~=&;!#$%^(){}<>'


# -------------------------
# Aliases
# -------------------------
alias c="clear"

alias ls="eza"
alias lsa="ls -lAhF"
alias l="ls -lAhF -G --group-directories-first"

alias gs="git status"
alias gd="git diff"
alias gl="git log --graph"
alias gl1="git log --graph --oneline --decorate --all"
# TODO: add git macro to git config instead of aliases

alias tree="tree -C -F"
alias tr1="tree -L 1"
alias tr2="tree -L 2"
alias tr3="tree -L 3"
alias tr4="tree -L 4"

# tmux shortcuts
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

# --- COMPLETION ---
# --- Zsh completion (Bash-like behavior) ---
autoload -Uz compinit
compinit

# behave like Bash: complete if unique, list on double TAB
unsetopt MENU_COMPLETE         # no cycling
unsetopt AUTO_MENU             # don't auto-select
setopt COMPLETE_IN_WORD        # bash-style behavior

# show colored matches (LS_COLORS)
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

# TAB does: try-complete on 1st press, list on 2nd
bindkey '^I' complete-word
