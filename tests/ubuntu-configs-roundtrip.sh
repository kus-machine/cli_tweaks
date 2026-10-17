#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Round trip of the Ubuntu dotfiles in a throwaway $HOME:
#
#   install --configs  x2   ->  our files deployed, originals captured ONCE
#   uninstall --configs x2  ->  originals back byte for byte, ours gone,
#                               empty dirs pruned, the repeat changes nothing
#
# It is the check the owner ran by hand on the laptop (2026-10-18), and it
# guards golden rules 5 and 7 in CLAUDE.md. It also covers the pre-manifest
# case: a `<file>.bak` left by the old installer counts as the original.
#
# Needs bash, jq and coreutils -- no sudo, nothing outside the temp dir is
# touched. Run it locally or let CI run it (.github/workflows/check.yml):
#
#   tests/ubuntu-configs-roundtrip.sh
# ---------------------------------------------------------------------------
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

export HOME="$T/home"
unset XDG_STATE_HOME XDG_CONFIG_HOME
mkdir -p "$HOME"

fails=0
pass() { printf '  \033[32mok\033[0m   %s\n' "$*"; }
fail() { printf '  \033[31mFAIL\033[0m %s\n' "$*"; fails=$((fails + 1)); }
same() {   # same <file> <file> <what>
    if cmp -s "$1" "$2"; then pass "$3"; else fail "$3 ($1 vs $2)"; fi
}
gone() {   # gone <path> <what>
    if [[ -e "$1" ]]; then fail "$2 ($1 still there)"; else pass "$2"; fi
}
snapshot() {   # every file under $HOME except the state dir, with checksums
    (cd "$HOME" && find . -path ./.local/state -prune -o -type f -print0 |
        sort -z | xargs -0 -r sha1sum)
}
quiet() {      # run, show the output only when it fails
    local out
    if ! out="$("$@" 2>&1)"; then
        printf '%s\n' "$out"
        fail "command failed: $*"
        exit 1
    fi
}

# --- the "user's machine" before cli_tweaks --------------------------------
# .bashrc: a plain original. .bash_aliases: the old pre-manifest installer
# left the original as .bash_aliases.bak and its own version in place.
# Nothing else exists (.tmux.conf, .blerc, lesskey ... have no original).
printf '# my own bashrc\nalias ll="ls -l"\n' > "$HOME/.bashrc"
printf 'alias htop=btop\n'                  > "$HOME/.bash_aliases.bak"
printf '# an old cli_tweaks deploy\n'        > "$HOME/.bash_aliases"
cp "$HOME/.bashrc"           "$T/orig.bashrc"
cp "$HOME/.bash_aliases.bak" "$T/orig.bash_aliases"

echo "== install --configs, twice"
quiet "$REPO/Ubuntu24/install.sh" --configs
quiet "$REPO/Ubuntu24/install.sh" --configs
C="$REPO/Ubuntu24/configs"
same "$HOME/.bashrc"                       "$C/.bashrc"            ".bashrc deployed"
same "$HOME/.bash_aliases"                 "$C/.bash_aliases"      ".bash_aliases deployed"
same "$HOME/.tmux.conf"                    "$C/.tmux.conf"         ".tmux.conf deployed"
same "$HOME/.blerc"                        "$C/.blerc"             ".blerc deployed"
same "$HOME/.config/cli_tweaks/lesskey"    "$REPO/shared/lesskey"  "lesskey deployed"
P="$HOME/.local/state/cli_tweaks/pristine"
same "$P/.bashrc"       "$T/orig.bashrc"       "pristine .bashrc is the user's, not ours (2nd run did not recapture)"
same "$P/.bash_aliases" "$T/orig.bash_aliases" "pristine .bash_aliases is the old .bak"

echo "== uninstall --configs"
quiet "$REPO/Ubuntu24/uninstall.sh" --configs
same "$HOME/.bashrc"       "$T/orig.bashrc"       ".bashrc restored"
same "$HOME/.bash_aliases" "$T/orig.bash_aliases" ".bash_aliases restored from the .bak"
gone "$HOME/.tmux.conf"            ".tmux.conf removed (had no original)"
gone "$HOME/.blerc"                ".blerc removed (had no original)"
gone "$HOME/.config/cli_tweaks"    ".config/cli_tweaks pruned"
gone "$HOME/.config/bat"           ".config/bat pruned"
snapshot > "$T/after1"

echo "== uninstall --configs again"
quiet "$REPO/Ubuntu24/uninstall.sh" --configs
snapshot > "$T/after2"
if cmp -s "$T/after1" "$T/after2"; then
    pass "second uninstall changed nothing"
else
    fail "second uninstall changed files:"; diff "$T/after1" "$T/after2" || true
fi

echo
if [[ $fails -eq 0 ]]; then
    echo "all checks passed"
else
    echo "$fails check(s) failed"
    exit 1
fi
