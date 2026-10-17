#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# LEGACY -- not maintained since 2026-10-18 (see README.md next to it).
#
# Alacritty + its config + the "Open in Alacritty" Files-menu item, as the
# Ubuntu installer did it before WezTerm became the only terminal there.
# Still uses Ubuntu24/scripts/common.sh, so whatever it installs lands in the
# manifest and Ubuntu24/uninstall.sh reverts it like anything else.
#
#   legacy/alacritty/install-alacritty.sh
#
# It does NOT make Alacritty the default terminal (Ctrl+Alt+T); for that:
#   sudo update-alternatives --set x-terminal-emulator /usr/bin/alacritty
# ---------------------------------------------------------------------------
set -euo pipefail

LEGACY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LEGACY_DIR/../.." && pwd)"
source "$REPO_ROOT/Ubuntu24/scripts/common.sh"

apt_install_tracked alacritty

record_dir "$HOME/.config/alacritty"
deploy_file "$LEGACY_DIR/alacritty.toml" "$HOME/.config/alacritty/alacritty.toml"

# "Open in Alacritty" in the Files right-click menu (a nautilus-python
# extension; restart Files once with `nautilus -q`).
apt_install_tracked python3-nautilus
deploy_file "$LEGACY_DIR/cli_tweaks_terminal.py" \
    "$HOME/.local/share/nautilus-python/extensions/cli_tweaks_terminal.py"

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
ok "alacritty installed (legacy, unmaintained)"
echo "   to make it the default terminal (Ctrl+Alt+T):"
echo "     sudo update-alternatives --set x-terminal-emulator /usr/bin/alacritty"
