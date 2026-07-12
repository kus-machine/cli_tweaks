#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT_DIR/.." && pwd)"

curl -sS https://starship.rs/install.sh | sh

mkdir -p "$HOME/.config"

# starship.toml is shared across Linux/macOS/Windows (see repo shared/)
install -m 644 \
    "$REPO_ROOT/shared/starship.toml" \
    "$HOME/.config/starship.toml"

echo "Starship installed."