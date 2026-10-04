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
# Homebrew lives in /opt/homebrew on Apple Silicon and /usr/local on Intel.
# Source whichever copy exists; a missing plugin is skipped, not an error.
# (zsh-syntax-highlighting is sourced at the very END of this file.)
# NOTE: changed blind from Linux -- still needs validation on real mac hardware.
# Autosuggestions
for __f in /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
           /usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh; do
    [[ -f $__f ]] && { source "$__f"; break; }
done
unset __f

# FZF
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh


# -------------------------
# Keybindings
# -------------------------
bindkey "^[b" backward-word      # Alt+B = jump back one word
bindkey "^[f" forward-word       # Alt+F = jump forward one word
bindkey "^[d" kill-word          # Alt+D = delete next word

# Word jumps / word deletion, matching Linux (ble.sh) and Windows (PSReadLine).
# Ctrl+Backspace reaches the shell as the byte ^H in Alacritty/iTerm2 (macOS
# Terminal.app cannot distinguish it from plain Backspace); Ctrl+Del and
# Ctrl+arrows arrive as xterm-style CSI sequences. Alt+Backspace is zsh's
# default backward-kill-word already -- kept explicit for the record.
# NOTE: added blind from Linux -- still needs validation on real mac hardware.
bindkey '^[[1;5C' forward-word         # Ctrl+Right
bindkey '^[[1;5D' backward-word        # Ctrl+Left
bindkey '^H' backward-kill-word        # Ctrl+Backspace
bindkey '^[^?' backward-kill-word      # Alt+Backspace
bindkey '^[[3;5~' kill-word            # Ctrl+Del
bindkey '^[[3~' delete-char            # Del (often unbound in zsh by default)

# UP/DOWN: prefix history search on everything typed so far, cursor at the end
# -- the same as bash/ble.sh on Ubuntu and PSReadLine on Windows.
# NOT zsh's `history-search-backward`: that one matches only the FIRST WORD of
# the line, so `git com`+UP would walk through every `git ...` command.
# up/down-line-or-beginning-search match up to the cursor and (zstyle
# leave-cursor, default on) then jump to the end of the line. Both the CSI
# (^[[A) and the application-mode (^[OA) arrow sequences are bound.
# NOTE: changed blind from Linux -- still needs validation on real mac hardware.
autoload -U up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[OA' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search
bindkey '^[OB' down-line-or-beginning-search

# Make Zsh treat / as a word separator (like bash)
WORDCHARS='*?_[]~=&;!#$%^(){}<>'


# -------------------------
# Aliases
# -------------------------
alias c="clear"

alias ls="eza"
# No -h: for eza that is --header (a column-title row), not "human-readable".
alias lsa="ls -lAF"
alias l="ls -lAF -G --group-directories-first"

alias gs="git status"
alias gd="git diff"
alias gl="git log --graph"
alias gl1="git log --graph --oneline --decorate --all"
# TODO: add git macro to git config instead of aliases

# tree [depth] [args...] -- eza's tree view; a leading number is the depth:
#   tree 3 /etc  ==  eza --tree --level=3 /etc
# tree1 .. tree9 are shorthands: tree3 /etc == tree 3 /etc. Same as Ubuntu.
# Shadows the brew `tree` binary interactively; `command tree` still reaches it.
# (Replaces the old `alias tree="tree -C -F"` + tr1..tr4.)
# unalias first: an alias would be expanded inside the definition below, and
# would win over the function at call time.
# NOTE: changed blind from Linux -- still needs validation on real mac hardware.
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


# -------------------------
# Syntax highlighting  --  MUST stay the last thing in this file
# -------------------------
# zsh-syntax-highlighting wraps the ZLE widgets that exist when it is sourced;
# widgets created after it (fzf's, the history-search ones above) would not
# refresh the highlighting. Same Apple Silicon / Intel lookup as the plugins
# block at the top.
for __f in /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
           /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh; do
    [[ -f $__f ]] && { source "$__f"; break; }
done
unset __f
