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

# Zoxide (better cd)
# eval "$(zoxide init zsh)"

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
# Make Zsh treat / as a word separator (like bash)
WORDCHARS='*?_[]~=&;!#$%^(){}<>'


# -------------------------
# Aliases
# -------------------------
alias c="clear"
alias cls="clear"

# alias ls="ls -G"
alias lsa="ls -lAhF"
alias ls="eza"
alias l="eza -lAh --group-directories-first"

alias gl="git log --graph"
alias gs="git status"
alias gl1="git log --graph --oneline --decorate --all"

# fancy ls list, colored, sorted by name etc

# colored folder and exe files in tree, use tree -L 3 for 3 levels
alias tree="tree -C"
alias treef="tree -C -F"

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
# unsetopt AUTO_LIST             # only list on 2nd TAB
setopt COMPLETE_IN_WORD        # bash-style behavior

# show only matching items (not everything)
# zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' \
#                                    'r:|[.]=* r:|=*'

# show colored matches (LS_COLORS)
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

# keep groups simple
zstyle ':completion:*' group-name ''

# TAB does: try-complete on 1st press, list on 2nd
bindkey '^I' complete-word
