#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/common.sh"

FONT_DIR="$HOME/.local/share/fonts"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

apt_install_tracked wget unzip fontconfig

mkdir -p "$FONT_DIR"

info "downloading FiraCode Nerd Font"
wget -q --show-progress -O "$TMP_DIR/FiraCode.zip" \
    https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip

info "installing into $FONT_DIR"
unzip -o -q "$TMP_DIR/FiraCode.zip" -d "$TMP_DIR/extracted"

# Record each font file we place so uninstall removes ours and nothing else.
# A file that is already there (you installed FiraCode Nerd Font yourself) is
# recorded as preexisting BEFORE we overwrite it, so uninstall keeps it.
shopt -s nullglob
for f in "$TMP_DIR"/extracted/*.ttf "$TMP_DIR"/extracted/*.otf; do
    dest="$FONT_DIR/$(basename "$f")"
    if [[ -e "$dest" ]]; then
        record_font "$dest" true
    else
        record_font "$dest" false
    fi
    install -m 644 "$f" "$dest"
done
shopt -u nullglob

fc-cache -f >/dev/null

echo
ok "FiraCode Nerd Font installed"
