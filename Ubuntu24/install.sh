#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
cat <<EOF
Ubuntu CLI Tweaks Installer

Usage:
  ./install.sh [options]

Options:
  --all          Install everything
  --packages     Install CLI packages
  --fonts        Install Nerd Fonts
  --starship     Install Starship + config
  --configs      Install Bash/Tmux configs
  --alacritty    Install Alacritty + config
  --help         Show this help

Examples:
  ./install.sh --all

  ./install.sh --packages --starship --configs

  ./install.sh --fonts --alacritty

No default action exists.
To install everything explicitly run:

  ./install.sh --all

EOF
}

if [[ $# -eq 0 ]]; then
    usage
    exit 1
fi

for arg in "$@"; do
    case "$arg" in
        --all)
            "$ROOT_DIR/scripts/install-packages.sh"
            "$ROOT_DIR/scripts/install-fonts.sh"
            "$ROOT_DIR/scripts/install-starship.sh"
            "$ROOT_DIR/scripts/install-configs.sh"
            "$ROOT_DIR/scripts/install-alacritty.sh"
            ;;

        --packages)
            "$ROOT_DIR/scripts/install-packages.sh"
            ;;

        --fonts)
            "$ROOT_DIR/scripts/install-fonts.sh"
            ;;

        --starship)
            "$ROOT_DIR/scripts/install-starship.sh"
            ;;

        --configs)
            "$ROOT_DIR/scripts/install-configs.sh"
            ;;

        --alacritty)
            "$ROOT_DIR/scripts/install-alacritty.sh"
            ;;

        --help|-h)
            usage
            exit 0
            ;;

        *)
            echo "Unknown option: $arg"
            echo
            usage
            exit 1
            ;;
    esac
done