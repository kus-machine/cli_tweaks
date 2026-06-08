#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "$ROOT_DIR/scripts/common.sh"

backup_file "$HOME/.bashrc"
backup_file "$HOME/.bash_aliases"
backup_file "$HOME/.tmux.conf"

install -m 644 \
    "$ROOT_DIR/configs/.bashrc" \
    "$HOME/.bashrc"

install -m 644 \
    "$ROOT_DIR/configs/.bash_aliases" \
    "$HOME/.bash_aliases"

install -m 644 \
    "$ROOT_DIR/configs/.tmux.conf" \
    "$HOME/.tmux.conf"

echo "Bash and Tmux configuration installed."