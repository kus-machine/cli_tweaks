#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT_DIR/.." && pwd)"
source "$ROOT_DIR/scripts/common.sh"

STARSHIP_BIN="/usr/local/bin/starship"

if command -v starship >/dev/null 2>&1; then
    ok "starship already installed ($(command -v starship)) - leaving it alone"
    record_bin "$(command -v starship)" true
else
    info "installing starship"
    # The upstream script installs to /usr/local/bin and needs sudo there.
    curl -sS https://starship.rs/install.sh | sh -s -- --yes
    record_bin "$STARSHIP_BIN" false
fi

# starship.toml is shared across Linux/macOS/Windows (see repo shared/)
deploy_file "$REPO_ROOT/shared/starship.toml" "$HOME/.config/starship.toml"

echo
ok "starship installed"
