#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/common.sh"

info "installing bash + tmux configuration"

deploy_file "$ROOT_DIR/configs/.bashrc"       "$HOME/.bashrc"
deploy_file "$ROOT_DIR/configs/.bash_aliases" "$HOME/.bash_aliases"
deploy_file "$ROOT_DIR/configs/.tmux.conf"    "$HOME/.tmux.conf"
# ble.sh's init file. Harmless when ble.sh is not installed: nothing reads it.
deploy_file "$ROOT_DIR/configs/.blerc"        "$HOME/.blerc"

echo
ok "bash and tmux configuration installed"
echo "   open a new terminal (or run: exec bash) to pick it up"
