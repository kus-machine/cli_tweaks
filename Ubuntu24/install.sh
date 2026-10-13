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
  --all          Everything except the terminal -- name one with it:
                   --all --alacritty   or   --all --wezterm
  --packages     Install CLI packages (apt)
  --fonts        Install FiraCode Nerd Font
  --starship     Install Starship + config
  --blesh        Install ble.sh (inline autosuggestions while you type)
  --configs      Install Bash/Tmux configs
  --help         Show this help

Terminal (exactly one per run -- it also becomes THE terminal: Ctrl+Alt+T
and "Open in ..." in the Files right-click menu):
  --alacritty    Alacritty + config; tabs and panes come from tmux
  --wezterm      WezTerm (nightly, upstream apt repo) + shared/wezterm.lua;
                 tabs and panes built in, same keys as tmux -- the Windows setup
  To try the other one, run the installer again with it: both stay
  installed, the one you named last is the default.

Everything installed is recorded in
  $MANIFEST
so ./uninstall.sh can revert it. Your original dotfiles are captured once,
on the first install, into
  $PRISTINE_DIR

Examples:
  ./install.sh --all --alacritty
  ./install.sh --all --wezterm
  ./install.sh --alacritty           (add / switch back to the other one)
  ./install.sh --packages --starship --configs

No default action exists, and --all never picks the terminal for you.

EOF
}

[[ $# -eq 0 ]] && { usage; exit 1; }

do_packages=0 do_fonts=0 do_starship=0 do_blesh=0 do_configs=0 do_alacritty=0 do_wezterm=0
do_all=0

while [[ $# -gt 0 ]]; do
    arg="$1"; shift
    case "$arg" in
        --all)       do_all=1; do_packages=1; do_fonts=1; do_starship=1; do_blesh=1; do_configs=1 ;;
        --packages)  do_packages=1  ;;
        --fonts)     do_fonts=1     ;;
        --starship)  do_starship=1  ;;
        --blesh)     do_blesh=1     ;;
        --configs)   do_configs=1   ;;
        --alacritty) do_alacritty=1 ;;
        --wezterm)   do_wezterm=1   ;;
        --help|-h)   usage; exit 0  ;;
        *)
            echo "Unknown option: $arg" >&2
            echo >&2
            usage >&2
            exit 1
            ;;
    esac
done

# --all means "the whole setup", and the setup differs by terminal: Alacritty
# + tmux, or WezTerm with tabs/panes of its own. Not a default to guess.
if [[ $do_all -eq 1 && $do_alacritty -eq 0 && $do_wezterm -eq 0 ]]; then
    echo "error: --all needs a terminal: add --alacritty or --wezterm" >&2
    echo >&2
    echo "  ./install.sh --all --alacritty   Alacritty, tabs and panes from tmux" >&2
    echo "  ./install.sh --all --wezterm     WezTerm, tabs and panes built in (as on Windows)" >&2
    exit 1
fi

# The terminal you name becomes the default one, so naming two would leave
# the default to flag order. One per run; the other one is a second run away.
if [[ $do_alacritty -eq 1 && $do_wezterm -eq 1 ]]; then
    echo "error: name one terminal per run - it becomes the default (Ctrl+Alt+T)." >&2
    echo "  To have both: install one, then run ./install.sh --<the other>;" >&2
    echo "  the last one installed is the default." >&2
    exit 1
fi

# Fixed order, each component at most once, regardless of flag order. (The
# previous version looped over $@ and ran a component once per matching flag,
# so `--all --packages` did the apt run twice.)
if [[ $do_packages  -eq 1 ]]; then "$ROOT_DIR/scripts/install-packages.sh";  fi
if [[ $do_fonts     -eq 1 ]]; then "$ROOT_DIR/scripts/install-fonts.sh";     fi
if [[ $do_starship  -eq 1 ]]; then "$ROOT_DIR/scripts/install-starship.sh";  fi
# before --configs: the .bashrc it deploys sources ble.sh if it is there.
if [[ $do_blesh     -eq 1 ]]; then "$ROOT_DIR/scripts/install-blesh.sh";     fi
if [[ $do_configs   -eq 1 ]]; then "$ROOT_DIR/scripts/install-configs.sh";   fi
if [[ $do_alacritty -eq 1 ]]; then "$ROOT_DIR/scripts/install-alacritty.sh"; fi
if [[ $do_wezterm   -eq 1 ]]; then "$ROOT_DIR/scripts/install-wezterm.sh";   fi
# ...and the one just installed becomes the desktop's terminal.
if [[ $do_alacritty -eq 1 ]]; then "$ROOT_DIR/scripts/install-default-terminal.sh" alacritty; fi
if [[ $do_wezterm   -eq 1 ]]; then "$ROOT_DIR/scripts/install-default-terminal.sh" wezterm;   fi

echo
info "done. manifest: $MANIFEST"
echo "   revert with: $ROOT_DIR/uninstall.sh --configs   (or --full)"
