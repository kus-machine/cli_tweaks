#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT_DIR/.." && pwd)"
source "$ROOT_DIR/scripts/common.sh"

apt_install_tracked alacritty

record_dir "$HOME/.config/alacritty"

# alacritty.toml is shared across Linux/macOS/Windows (see repo shared/)
deploy_file "$REPO_ROOT/shared/alacritty.toml" "$HOME/.config/alacritty/alacritty.toml"

# Alacritty is a GPU terminal: it needs a working OpenGL/GLX context and will
# refuse to open a window without one. A broken GPU driver shows up here as
# "BadValue ... BadAttribute" and looks like a config bug, but is not one.
if command -v glxinfo >/dev/null 2>&1; then
    if ! glxinfo -B >/dev/null 2>&1; then
        warn "OpenGL/GLX is not working on this machine - Alacritty will fail to start."
        warn "This is a graphics-driver problem, not an Alacritty config problem."
        warn "Check: glxinfo -B ; nvidia-smi ; then reboot after a driver upgrade."
    fi
fi

echo
ok "alacritty installed"
echo "   to make it the default terminal:"
echo "     sudo update-alternatives --config x-terminal-emulator"
