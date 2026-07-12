#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT_DIR/.." && pwd)"

sudo apt install -y alacritty

mkdir -p "$HOME/.config/alacritty"

# alacritty.toml is shared across Linux/macOS/Windows (see repo shared/)
install -m 644 \
    "$REPO_ROOT/shared/alacritty.toml" \
    "$HOME/.config/alacritty/alacritty.toml"

echo
echo "To make Alacritty the default terminal:"
echo "sudo update-alternatives --config x-terminal-emulator"