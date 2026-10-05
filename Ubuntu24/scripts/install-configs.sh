#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT_DIR/.." && pwd)"
source "$ROOT_DIR/scripts/common.sh"

info "installing bash + tmux configuration"

deploy_file "$ROOT_DIR/configs/.bashrc"       "$HOME/.bashrc"
deploy_file "$ROOT_DIR/configs/.bash_aliases" "$HOME/.bash_aliases"
deploy_file "$ROOT_DIR/configs/.tmux.conf"    "$HOME/.tmux.conf"
# ble.sh's init file. Harmless when ble.sh is not installed: nothing reads it.
deploy_file "$ROOT_DIR/configs/.blerc"        "$HOME/.blerc"

# bat colour themes (shared/bat/themes, see the README there):
# tokyonight_night is the default -- BAT_THEME in .bashrc -- and synthwave84
# an alternative. bat picks new theme files up only after a cache rebuild.
record_dir "$HOME/.config/bat"
for theme in "$REPO_ROOT"/shared/bat/themes/*.tmTheme; do
    deploy_file "$theme" "$HOME/.config/bat/themes/$(basename "$theme")"
done
bat_refresh_theme_cache

echo
ok "bash and tmux configuration installed"
echo "   open a new terminal (or run: exec bash) to pick it up"
