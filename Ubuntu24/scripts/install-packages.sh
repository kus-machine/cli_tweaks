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
    fzf \
    fd-find \
    ripgrep \
    btop

echo
ok "packages installed"
