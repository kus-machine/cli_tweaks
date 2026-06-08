#!/usr/bin/env bash
set -euo pipefail

sudo apt update

sudo apt install -y \
    curl \
    git \
    tmux \
    eza \
    tree \
    fzf \
    fd-find \
    ripgrep \
    btop