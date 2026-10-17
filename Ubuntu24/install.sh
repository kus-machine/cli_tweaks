#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT_DIR/scripts/common.sh"

usage() {
cat <<EOF
Ubuntu CLI Tweaks Installer

Usage:
  ./install.sh [options]

Options:
  --all          Everything below, WezTerm included
  --packages     Install CLI packages (apt)
  --fonts        Install FiraCode Nerd Font
  --starship     Install Starship + config
  --blesh        Install ble.sh (inline autosuggestions while you type)
  --configs      Install Bash/Tmux configs
  --wezterm      WezTerm (nightly, upstream apt repo) + shared/wezterm.lua;
                 tabs and panes built in, same keys as tmux -- the Windows
                 setup. It also becomes THE terminal: Ctrl+Alt+T and
                 "Open in WezTerm" in the Files right-click menu.
  --help         Show this help

Alacritty is no longer an option (2026-10-18): see legacy/alacritty/.

Everything installed is recorded in
  $MANIFEST
so ./uninstall.sh can revert it. Your original dotfiles are captured once,
on the first install, into
  $PRISTINE_DIR

Examples:
  ./install.sh --all
  ./install.sh --packages --starship --configs

No default action exists.

EOF
}

[[ $# -eq 0 ]] && { usage; exit 1; }

do_packages=0 do_fonts=0 do_starship=0 do_blesh=0 do_configs=0 do_wezterm=0
while [[ $# -gt 0 ]]; do
    arg="$1"; shift
    case "$arg" in
        --all)       do_packages=1; do_fonts=1; do_starship=1; do_blesh=1; do_configs=1; do_wezterm=1 ;;
        --packages)  do_packages=1  ;;
        --fonts)     do_fonts=1     ;;
        --starship)  do_starship=1  ;;
        --blesh)     do_blesh=1     ;;
        --configs)   do_configs=1   ;;
        --wezterm)   do_wezterm=1   ;;
        --alacritty)
            echo "--alacritty is gone: Ubuntu has WezTerm only since 2026-10-18." >&2
            echo "The old Alacritty setup is parked, unmaintained, in legacy/alacritty/" >&2
            echo "(its README says how to try it again)." >&2
            exit 1
            ;;
        --help|-h)   usage; exit 0  ;;
        *)
            echo "Unknown option: $arg" >&2
            echo >&2
            usage >&2
            exit 1
            ;;
    esac
done

# Fixed order, each component at most once, regardless of flag order. (The
# previous version looped over $@ and ran a component once per matching flag,
# so `--all --packages` did the apt run twice.)
if [[ $do_packages  -eq 1 ]]; then "$ROOT_DIR/scripts/install-packages.sh";  fi
if [[ $do_fonts     -eq 1 ]]; then "$ROOT_DIR/scripts/install-fonts.sh";     fi
if [[ $do_starship  -eq 1 ]]; then "$ROOT_DIR/scripts/install-starship.sh";  fi
# before --configs: the .bashrc it deploys sources ble.sh if it is there.
if [[ $do_blesh     -eq 1 ]]; then "$ROOT_DIR/scripts/install-blesh.sh";     fi
if [[ $do_configs   -eq 1 ]]; then "$ROOT_DIR/scripts/install-configs.sh";   fi
if [[ $do_wezterm   -eq 1 ]]; then "$ROOT_DIR/scripts/install-wezterm.sh";   fi
# ...and it becomes the desktop's terminal.
if [[ $do_wezterm   -eq 1 ]]; then "$ROOT_DIR/scripts/install-default-terminal.sh"; fi

echo
info "done. manifest: $MANIFEST"
echo "   revert with: $ROOT_DIR/uninstall.sh --configs   (or --full)"
