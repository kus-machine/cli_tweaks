#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# cli_tweaks - Ubuntu uninstaller / return-to-default.
#
# Reverts what install.sh did, driven by the manifest it wrote, so it NEVER
# removes anything that was already on the machine before you ran the installer.
#
# Two modes (mirrors windows/uninstall.ps1):
#   --configs   Restore your original dotfiles only. Leaves every tool
#               installed. This is the "make my shell normal again" button.
#   --full      --configs, PLUS apt-remove the packages WE installed (never the
#               ones flagged pre-existing), remove the fonts we placed, and
#               remove starship if we installed it.
#
# --dry-run prints what would happen and changes nothing.
# ---------------------------------------------------------------------------
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT_DIR/scripts/common.sh"

DRY_RUN=0
MODE=""

usage() {
cat <<EOF
cli_tweaks - Ubuntu uninstaller

Usage:
  ./uninstall.sh --configs [--dry-run]
  ./uninstall.sh --full    [--dry-run]

Options:
  --configs   Restore original .bashrc / .bash_aliases / .tmux.conf /
              starship.toml / alacritty.toml from the pristine copies taken on
              first install. Tools stay installed.
  --full      Everything --configs does, plus remove the apt packages, fonts
              and starship binary that THIS installer added. Anything that was
              already present is left untouched.
  --dry-run   Show what would change; touch nothing.
  --help      Show this help.

Manifest:  $MANIFEST
Pristine:  $PRISTINE_DIR
EOF
}

[[ $# -eq 0 ]] && { usage; exit 1; }

for arg in "$@"; do
    case "$arg" in
        --configs)  MODE="configs" ;;
        --full)     MODE="full"    ;;
        --dry-run)  DRY_RUN=1      ;;
        --help|-h)  usage; exit 0  ;;
        *) echo "Unknown option: $arg" >&2; echo >&2; usage >&2; exit 1 ;;
    esac
done

[[ -n "$MODE" ]] || { echo "Pick --configs or --full." >&2; exit 1; }

run() {
    if [[ $DRY_RUN -eq 1 ]]; then
        printf '\033[35m  would:\033[0m %s\n' "$*"
    else
        "$@"
    fi
}

if [[ ! -f "$MANIFEST" ]]; then
    warn "no manifest at $MANIFEST"
    echo
    echo "This uninstaller only reverts what a manifest-writing install recorded,"
    echo "so it will not guess. If you installed before manifests existed, the"
    echo "old installer left timestamped backups next to each file:"
    echo
    for f in "$HOME/.bashrc" "$HOME/.bash_aliases" "$HOME/.tmux.conf" \
             "$HOME/.config/starship.toml" "$HOME/.config/alacritty/alacritty.toml"; do
        shopt -s nullglob
        baks=("$f".bak*)
        shopt -u nullglob
        if [[ ${#baks[@]} -gt 0 ]]; then
            echo "  $f"
            printf '      %s\n' "${baks[@]}"
        fi
    done
    echo
    echo "The OLDEST of those is your original. Restore by hand, e.g.:"
    echo "  cp ~/.bashrc.bak.20260608_154748 ~/.bashrc"
    exit 1
fi

ensure_jq
info "loaded manifest: $(jq -r '"\(.files|length) files, \(.packages|length) packages, \(.fonts|length) fonts"' "$MANIFEST")"
[[ $DRY_RUN -eq 1 ]] && warn "dry run - nothing will be changed"

# --- 1. restore config files ----------------------------------------------

info "restoring configuration files"
while IFS=$'\t' read -r path pristine; do
    [[ -n "$path" ]] || continue
    if [[ "$pristine" == "null" || -z "$pristine" ]]; then
        # There was no file here before we installed - remove ours.
        if [[ -e "$path" ]]; then
            echo "  remove (had no original): $path"
            run rm -f "$path"
        fi
    elif [[ -f "$pristine" ]]; then
        echo "  restore: $pristine -> $path"
        run cp -a "$pristine" "$path"
    else
        warn "pristine copy missing for $path (expected $pristine) - leaving as is"
    fi
done < <(jq -r '.files[] | [.id, (.pristine // "null")] | @tsv' "$MANIFEST")

if [[ "$MODE" == "configs" ]]; then
    echo
    ok "configs reverted. Open a new terminal (or run: exec bash)."
    echo "   Tools are still installed. Use --full to remove them too."
    exit 0
fi

# --- 2. fonts --------------------------------------------------------------

info "removing fonts we installed"
mapfile -t fonts < <(jq -r '.fonts[].id' "$MANIFEST")
if [[ ${#fonts[@]} -eq 0 ]]; then
    echo "  (none recorded)"
else
    for f in "${fonts[@]}"; do
        [[ -e "$f" ]] && { echo "  remove: $f"; run rm -f "$f"; }
    done
    run fc-cache -f
fi

# --- 3. standalone binaries (starship) -------------------------------------

info "removing binaries we installed"
mapfile -t bins < <(jq -r '.bins[] | select(.preexisting == false) | .id' "$MANIFEST")
if [[ ${#bins[@]} -eq 0 ]]; then
    echo "  (none - nothing installed by us, or all were pre-existing)"
else
    for b in "${bins[@]}"; do
        [[ -e "$b" ]] && { echo "  remove: $b"; run sudo rm -f "$b"; }
    done
fi

# --- 4. apt packages -------------------------------------------------------

info "removing apt packages we installed"
mapfile -t pkgs < <(jq -r '.packages[] | select(.preexisting == false) | .id' "$MANIFEST")
if [[ ${#pkgs[@]} -eq 0 ]]; then
    echo "  (none - every package was already present before install)"
else
    echo "  ${pkgs[*]}"
    run sudo apt-get remove -y "${pkgs[@]}"
    run sudo apt-get autoremove -y
fi

# --- 5. manifest + pristine store ------------------------------------------
#
# Keep the pristine store. If the user re-installs later we want the ORIGINAL
# originals, not a snapshot of a half-reverted state. Only drop the manifest.

info "clearing manifest"
run rm -f "$MANIFEST"
echo "  kept pristine copies in $PRISTINE_DIR (delete by hand if you are sure)"

echo
ok "full uninstall complete. Open a new terminal."
