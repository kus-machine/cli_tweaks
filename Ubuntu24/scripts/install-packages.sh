#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/common.sh"

info "refreshing apt package lists"
sudo apt-get update

# bash-completion is listed explicitly: .bashrc sources it *before* fzf's
# completion, and without it fzf's hijacked completions have nothing to fall
# back to (Tab silently does nothing). See the comment block in configs/.bashrc.
apt_install_tracked \
    bash-completion \
    curl \
    git \
    jq \
    tmux \
    eza \
    tree \
    fzf \
    fd-find \
    ripgrep \
    btop

echo
ok "packages installed"
