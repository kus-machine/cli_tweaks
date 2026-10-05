alias gs='git status'
alias gd='git diff'
alias gl='git log --graph'

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

# bat = cat with syntax highlighting and line numbers. Ubuntu's package names
# the command `batcat` (an older, unrelated `bat` package took the name), so
# give it its real name back -- unless a real `bat` is installed already.
if command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then
    alias bat='batcat'
fi

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

# alert -- desktop notification when a long command finishes:
#   make; alert        sleep 5; alert
# Title "done" or "failed (exit N)", the command as the text, and a terminal
# or error icon. Forgot it on a running command? Ctrl+Z, then  fg; alert
#
# This was Ubuntu's stock `alias alert='notify-send --urgency=low ...'`. GNOME
# Shell shows LOW-urgency notifications only in the list under the clock --
# no pop-up banner -- so it looked like nothing happened. Rewritten as a
# function with normal urgency. `$?` must be read on its first line, before
# anything else overwrites it.
unalias alert 2>/dev/null
alert() {
    local status=$? cmd
    cmd=$(history 1 | sed -e 's/^ *[0-9]\+ *//; s/[;&|] *alert *$//')
    if ! command -v notify-send >/dev/null 2>&1; then
        echo "alert: notify-send not found (apt install libnotify-bin)" >&2
        return "$status"
    fi
    if (( status == 0 )); then
        notify-send --urgency=normal -i terminal "done" "$cmd"
    else
        notify-send --urgency=normal -i error "failed (exit $status)" "$cmd"
    fi
    return "$status"
}


# cli_tweaks_f1 -- what F1 runs (bound in ~/.blerc, readline fallback in
# ~/.bashrc): tldr for the command on the line being typed, tried as
# "cmd-subcommand" first (git commit -> git-commit), then "cmd", then man.
# $READLINE_LINE is the line; it is left untouched.
cli_tweaks_f1() {
    local -a w
    read -ra w <<< "${READLINE_LINE-}"
    local cmd=${w[0]-} sub=${w[1]-}
    [[ $cmd ]] || return 0      # empty line: nothing to explain
    if command -v tldr >/dev/null 2>&1; then
        if [[ $sub && $sub != -* ]] && tldr "$cmd-$sub" 2>/dev/null; then return; fi
        tldr "$cmd" 2>/dev/null && return
    fi
    man "$cmd" 2>/dev/null || echo "F1: no tldr page and no man page for '$cmd'"
}


# ===========================================================================
# Startup banner + `keys` cheatsheet
# ===========================================================================
# A reminder of what this setup can do, because the macros are easy to forget.
#   cli_tweaks_banner   the cat + the most-used commands; ~/.bashrc calls it
#                       once per new terminal (see the guard there)
#   keys                every command and hotkey, one screen-ish, via less
# Turn the banner off with  CLI_TWEAKS_BANNER=0  in ~/.bashrc.local.
#
# Keys are written out the way they are printed on the keyboard (Ctrl+T,
# Alt+C, Shift+PgUp), arrows as ← ↑ → ↓ -- no ^T / M-c shorthand.
#
# Colours are the Tokyo Night values from shared/alacritty.toml, sent as
# truecolor when the terminal says it supports it ($COLORTERM) and as the
# nearest 256-colour index otherwise.

# __cli_tweaks_fg <hex rrggbb> <256-colour fallback>  -- prints the escape
__cli_tweaks_fg() {
    if [[ ${COLORTERM-} == truecolor || ${COLORTERM-} == 24bit ]]; then
        printf '\e[38;2;%d;%d;%dm' "0x${1:0:2}" "0x${1:2:2}" "0x${1:4:2}"
    else
        printf '\e[38;5;%sm' "$2"
    fi
}

# __cli_tweaks_pad <text> <width>  -- spaces that pad <text> to <width>.
# printf's %-20s counts BYTES, so "↑ →" (3 bytes per arrow) would come out
# short; ${#text} counts characters in a UTF-8 locale.
__cli_tweaks_pad() {
    local n=$(( $2 - ${#1} ))
    (( n > 0 )) && printf '%*s' "$n" ''
}

# __cli_tweaks_colour_cmd <text> <cmd> <arg> <key> <sep>
# Prints the banner's command column with each word in its own colour, picked
# by what the word looks like -- so a new banner row needs no markup:
#   Ctrl+… Alt+… Shift+… F1 ← ↑ → ↓   a key         -> <key>
#   DIR TEXT CMD (all capitals)        an argument   -> <arg>
#   ·                                  a separator   -> <sep>
#   anything else                      a command     -> <cmd>
__cli_tweaks_colour_cmd() {
    local rest=$1 c_cmd=$2 c_arg=$3 c_key=$4 c_sep=$5 reset=$'\e[0m'
    local ws tok col
    while [[ $rest =~ ^([[:space:]]*)([^[:space:]]+)(.*)$ ]]; do
        ws=${BASH_REMATCH[1]} tok=${BASH_REMATCH[2]} rest=${BASH_REMATCH[3]}
        if [[ $tok == '·' ]]; then
            col=$c_sep
        elif [[ $tok =~ ^(Ctrl|Alt|Shift)\+ || $tok =~ ^F[0-9]+$ || $tok == [←↑→↓] ]]; then
            col=$c_key
        elif [[ $tok =~ ^[[:upper:]]+$ ]]; then
            col=$c_arg
        else
            col=$c_cmd
        fi
        printf '%s%s%s%s' "$ws" "$col" "$tok" "$reset"
    done
}

cli_tweaks_banner() {
    local cols
    cols=$(tput cols 2>/dev/null) || cols=80

    local cat_c title_c cmd_c arg_c key_c sep_c desc_c name_c reset=$'\e[0m'
    cat_c=$(__cli_tweaks_fg bb9af7 141)     # magenta  the cat
    title_c=$(__cli_tweaks_fg ff9e64 215)   # orange   the title line
    cmd_c=$(__cli_tweaks_fg 7aa2f7 111)     # blue     commands (as ble.sh shows them)
    arg_c=$(__cli_tweaks_fg 565f89 60)      # grey     ARGS you fill in
    key_c=$(__cli_tweaks_fg bb9af7 141)     # magenta  keys to press
    sep_c=$(__cli_tweaks_fg 565f89 60)      # grey     the · separators
    desc_c=$(__cli_tweaks_fg a9b1d6 146)    # soft fg  what it does
    name_c=$(__cli_tweaks_fg e0af68 179)    # yellow   the name, and the keys row

    # Too narrow for the cat (it needs 79 columns): one line, or nothing.
    if (( cols < 40 )); then
        return 0
    elif (( cols < 79 )); then
        printf '%s=^.^=%s %scli_tweaks%s %s· type%s %skeys%s %sfor every hotkey%s\n' \
            "$cat_c" "$reset" "$title_c" "$reset" "$desc_c" "$reset" \
            "$cmd_c" "$reset" "$desc_c" "$reset"
        return 0
    fi

    # ASCII cat by hjw (Hayley Jane Wakenshaw); her "hjw" signature in the
    # box was replaced by the owner's name, credited here instead.
    local -a cat
    mapfile -t cat <<'CAT'
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
CAT

    # Right-hand column: rows 3..11 are "command<TAB>what it does"; row 12,
    # below the cat, is `keys` -- in the name's yellow, so it reads as "and
    # here is where the full instructions continue" rather than one more item.
    local -a rows=(
        ''
        ''
        $'l  la  lss\tlist · +sizes · by size'
        $'tree3 DIR\ttree, 3 levels (tree1…9)'
        $'fin TEXT\tfind by name, from here'
        $'z DIR\tjump to a frequent folder'
        $'gs  gd  gl\tgit status · diff · log'
        $'t  ta  tn  tk\ttmux · attach · new · kill'
        $'Ctrl+T Ctrl+R Alt+C\tfzf: file · history · cd'
        $'↑  →  Alt+W\thistory · accept · copy'
        $'F1  ·  tldr CMD\texamples for a command'
        $'keys\tall commands & hotkeys'
    )

    local i line cmd desc
    for i in "${!rows[@]}"; do
        line=${cat[i]-}
        # Colour the name inside the box separately from the cat outline.
        line=${line//Andrii/${name_c}Andrii${cat_c}}
        line=${line//Pavliuk/${name_c}Pavliuk${cat_c}}
        printf '%s%s%s' "$cat_c" "$line" "$reset"
        if (( i == 0 )); then
            __cli_tweaks_pad "${cat[i]}" 31
            printf '%scli_tweaks · github.com/kus-machine/cli_tweaks%s' "$title_c" "$reset"
        elif [[ ${rows[i]-} ]]; then
            __cli_tweaks_pad "${cat[i]-}" 31
            cmd=${rows[i]%%$'\t'*} desc=${rows[i]#*$'\t'}
            if (( i == ${#rows[@]} - 1 )); then       # keys: one colour, all yellow
                printf '%s%s%s' "$name_c" "$cmd" "$reset"
                __cli_tweaks_pad "$cmd" 21
                printf '%s%s%s' "$name_c" "$desc" "$reset"
            else
                __cli_tweaks_colour_cmd "$cmd" "$cmd_c" "$arg_c" "$key_c" "$sep_c"
                __cli_tweaks_pad "$cmd" 21
                printf '%s%s%s' "$desc_c" "$desc" "$reset"
            fi
        fi
        printf '\n'
    done
}

# keys -- the full cheatsheet. Taller than a small window, so it goes through
# `less -FRX`: quits by itself when it fits on one screen (-F), keeps colours
# (-R) and leaves the text on screen afterwards (-X).
keys() {
    local head_c key_c desc_c reset=$'\e[0m'
    head_c=$(__cli_tweaks_fg 7aa2f7 111)
    key_c=$(__cli_tweaks_fg 73daca 79)
    desc_c=$(__cli_tweaks_fg a9b1d6 146)

    # "# Heading", blank lines, or "keys<TAB>description" -- an empty key
    # ("<TAB>more text") continues the description on the next line.
    local line k d
    while IFS= read -r line; do
        if [[ $line == '# '* ]]; then
            printf '%s%s%s\n' "$head_c" "${line#'# '}" "$reset"
        elif [[ $line == *$'\t'* ]]; then
            k=${line%%$'\t'*} d=${line#*$'\t'}
            printf '  %s%s%s' "$key_c" "$k" "$reset"
            __cli_tweaks_pad "$k" 26
            printf '%s%s%s\n' "$desc_c" "$d" "$reset"
        else
            printf '%s\n' "$line"
        fi
    done <<'KEYS' | less -FRX
# cli_tweaks · github.com/kus-machine/cli_tweaks

# COMMANDS
l  la  lss	list files · + folder sizes · biggest last
tree [N] [DIR]	tree, N levels deep · tree1 … tree9 = tree N
fin TEXT	find files by name, from the current folder
bat FILE	show a file with syntax colours and line numbers
tldr CMD	short ready-made examples instead of man (tldr tar)
z PART  ·  zi PART	jump to a visited folder by part of its name
	learns as you go: cd into it once, then  z cli
	works anywhere · zi = pick from a list · z - = back
gs  gd  gl	git status · git diff · git log graph
t  tls  ta	tmux · list sessions · attach to the first one
tn  tk	new tmux session · kill session (asks outside tmux)
top  htop	btop system monitor
c	clear the screen
CMD; alert	desktop popup when CMD finishes (done / failed)
	try:  sleep 5; alert   and switch windows
	forgot it? Ctrl+Z, then  fg; alert

# TYPING A COMMAND
→  End  Ctrl+F	accept the grey suggestion
Ctrl+→  Alt+F	accept one word of it
↑  ↓	history starting with what you typed
Tab Tab	menu of choices · type to narrow · Enter takes one
Esc  Ctrl+G	close the menu / search / suggestion
Ctrl+T  Ctrl+R  Alt+C	fzf: file · history line · folder to cd into
	with a preview on the side · Ctrl+/ hides it
** then Tab	fzf file picker inside any command, e.g.  vim **
Shift+← →  then Alt+W	select text · copy it (no selection = whole line)
Ctrl+Backspace	delete the word on the left (Alt+Backspace too)
Ctrl+Delete	delete the word on the right
Ctrl+Y	paste what you deleted last
Ctrl+← →	jump one word
F1	examples for the command you are typing (tldr)
	git commit + F1 -> git-commit · no page? opens man

# TMUX  (press Ctrl+B, release, then the key)
Alt+1 … Alt+9	go to tab N (or click it in the top bar)
Alt+T	new tab, in the current folder
Alt+N   Alt+K	rename the tab · close tab (asks: Enter = yes)
Ctrl+B w	all tabs with previews · ↑ ↓ then Enter
Ctrl+B |   Ctrl+B -	split the pane right · below
Alt+← ↑ → ↓	move between panes
Ctrl+B Ctrl+← ↑ → ↓	resize the pane (keep pressing the arrow)
Ctrl+B z	zoom the pane to the whole tab and back
Ctrl+B ?	all tmux commands list (q to close)
Shift+PgUp, mouse wheel	scroll back (q or Esc to stop)
drag, 2×click, 3×click	copy the selection · word · line
Ctrl+B d   Ctrl+B r	detach (session keeps running) · reload config
Ukrainian layout	the same keys work (Ctrl+B ґ splits right)

# TERMINAL
select with the mouse	copied already · Ctrl+Shift+V pastes
middle click	paste the current selection
paste one line	its trailing newline is dropped: no MULTILINE
Ukrainian layout	Ctrl+… and Alt+… keys work as on the Latin one
KEYS
}
