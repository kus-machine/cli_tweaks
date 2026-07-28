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
  --all          Install everything
  --packages     Install CLI packages (apt)
  --fonts        Install FiraCode Nerd Font
  --starship     Install Starship + config
  --configs      Install Bash/Tmux configs
  --alacritty    Install Alacritty + config
  --help         Show this help

Everything installed is recorded in
  $MANIFEST
so ./uninstall.sh can revert it. Your original dotfiles are captured once,
on the first install, into
  $PRISTINE_DIR

Examples:
  ./install.sh --all
  ./install.sh --packages --starship --configs
  ./install.sh --fonts --alacritty

No default action exists. To install everything explicitly run:

  ./install.sh --all

EOF
}

[[ $# -eq 0 ]] && { usage; exit 1; }

do_packages=0 do_fonts=0 do_starship=0 do_configs=0 do_alacritty=0

for arg in "$@"; do
    case "$arg" in
        --all)       do_packages=1; do_fonts=1; do_starship=1; do_configs=1; do_alacritty=1 ;;
        --packages)  do_packages=1  ;;
        --fonts)     do_fonts=1     ;;
        --starship)  do_starship=1  ;;
        --configs)   do_configs=1   ;;
        --alacritty) do_alacritty=1 ;;
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
if [[ $do_configs   -eq 1 ]]; then "$ROOT_DIR/scripts/install-configs.sh";   fi
if [[ $do_alacritty -eq 1 ]]; then "$ROOT_DIR/scripts/install-alacritty.sh"; fi

echo
info "done. manifest: $MANIFEST"
echo "   revert with: $ROOT_DIR/uninstall.sh --configs   (or --full)"
