#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

curl -sS https://starship.rs/install.sh | sh

mkdir -p "$HOME/.config"

install -m 644 \
    "$ROOT_DIR/configs/starship.toml" \
    "$HOME/.config/starship.toml"

echo "Starship installed."