#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/common.sh"

info "refreshing apt package lists"
sudo apt-get update

# bash-completion is listed explicitly: .bashrc sources it *before* fzf's
# completion, and without it fzf's hijacked completions have nothing to fall
# back to (Tab silently does nothing). See the comment block in configs/.bashrc.
# xclip is what .tmux.conf and ~/.blerc pipe copies into. Without it, tmux falls
# back to its OSC 52 escape (which Alacritty honours only sometimes) and Alt+W
# on the command line has nowhere to put the text.
apt_install_tracked \
    bash-completion \
    curl \
    git \
    jq \
    xclip \
    tmux \
    eza \
    tree \
    bat \
    fzf \
    fd-find \
    ripgrep \
    zoxide \
    tealdeer \
    btop

# tldr pages: tealdeer (the `tldr` command) ships without them and only says
# "run tldr --update" until they are downloaded (~30 MB, English only), so
# fetch them once now -- as you, into ~/.cache/tealdeer. A cache dir we create
# is ours to delete on uninstall --full; refresh it now and then with
# `tldr --update`.
TLDR_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/tealdeer"
if command -v tldr >/dev/null 2>&1 && [[ ! -d "$TLDR_CACHE" ]]; then
    info "downloading tldr pages"
    if tldr --update >/dev/null; then
        record_dir "$TLDR_CACHE" false
    else
        warn "tldr --update failed (offline?) - run it later by hand"
    fi
fi

echo
ok "packages installed"
