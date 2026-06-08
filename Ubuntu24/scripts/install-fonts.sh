#!/usr/bin/env bash
set -euo pipefail

TMP_DIR="$(mktemp -d)"

mkdir -p "$HOME/.local/share/fonts"

wget -O "$TMP_DIR/FiraCode.zip" \
https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip

unzip -o "$TMP_DIR/FiraCode.zip" \
-d "$HOME/.local/share/fonts"

fc-cache -fv

rm -rf "$TMP_DIR"