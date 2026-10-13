#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Make Alacritty or WezTerm THE terminal of the desktop. Not a flag of its
# own: install.sh runs it after --alacritty / --wezterm -- the terminal you
# install is the one you want (the owner's rule, 2026-10-13).
#
# Two places decide which terminal opens, and neither is a per-user setting:
#
#   Ctrl+Alt+T         GNOME runs `x-terminal-emulator`, a system-wide
#                      Debian "alternative" (update-alternatives). Installing
#                      a terminal only REGISTERS it there -- on SF-WS1181 it
#                      had been pinned to Alacritty by hand, so WezTerm never
#                      got it.
#   Files, right click "Open in Terminal" comes from nautilus-extension-gnome-
#                      terminal and always opens GNOME Terminal. We cannot
#                      redirect it; we add our own item next to it
#                      (configs/nautilus/cli_tweaks_terminal.py, "Open in
#                      Alacritty") -- WezTerm's package already ships "Open in
#                      WezTerm". Both are nautilus-python extensions, so
#                      python3-nautilus is installed for them. GNOME's item
#                      next to ours is welcome: two explicit choices.
#
# The alternative's state BEFORE our first change (auto/manual + the target)
# is recorded once; uninstall puts it back.
# ---------------------------------------------------------------------------
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/common.sh"

ALT_NAME="x-terminal-emulator"

case "${1-}" in
    alacritty) target=/usr/bin/alacritty;         label=Alacritty ;;
    # wezterm's own entry: a wrapper that opens in the caller's folder
    wezterm)   target=/usr/bin/open-wezterm-here; label=WezTerm ;;
    *) die "usage: install-default-terminal.sh alacritty|wezterm (run by install.sh)" ;;
esac
term="$1"

[[ -x "$target" ]] || die "$term is not installed ($target missing) - run ./install.sh --$term first"
update-alternatives --list "$ALT_NAME" 2>/dev/null | grep -qxF "$target" ||
    die "$target is not registered as $ALT_NAME (reinstall the $term package)"

# --- 1. Ctrl+Alt+T: the x-terminal-emulator alternative --------------------

record_alternative "$ALT_NAME"
current="$(readlink -f "/etc/alternatives/$ALT_NAME" || true)"
if [[ "$current" == "$target" ]]; then
    ok "$ALT_NAME already -> $target"
else
    info "$ALT_NAME: ${current:-none} -> $target (Ctrl+Alt+T)"
    sudo update-alternatives --set "$ALT_NAME" "$target"
fi

# --- 2. Files (Nautilus) right-click menu ----------------------------------

apt_install_tracked python3-nautilus
deploy_file "$ROOT_DIR/configs/nautilus/cli_tweaks_terminal.py" \
    "$HOME/.local/share/nautilus-python/extensions/cli_tweaks_terminal.py"

echo
ok "$term is the default terminal"
echo "   Ctrl+Alt+T opens it now. For the Files right-click menu (\"Open in"
echo "   $label\"), restart Files once:  nautilus -q"
echo "   GNOME's own \"Open in Terminal\" item stays and still opens GNOME Terminal."
