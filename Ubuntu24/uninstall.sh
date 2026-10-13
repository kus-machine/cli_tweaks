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
#               remove starship / ble.sh / the WezTerm apt repository if
#               we installed them.
#
# --dry-run prints what would happen and changes nothing.
# ---------------------------------------------------------------------------
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT_DIR/scripts/common.sh"

DRY_RUN=0
ASSUME_YES=0
MODE=""

usage() {
cat <<EOF
cli_tweaks - Ubuntu uninstaller

Usage:
  ./uninstall.sh --configs [--dry-run]
  ./uninstall.sh --full    [--dry-run]

Options:
  --configs   Restore original .bashrc / .bash_aliases / .blerc / .tmux.conf /
              starship.toml / alacritty.toml / wezterm.lua from the pristine
              copies taken on first install, and the default terminal
              (Ctrl+Alt+T) as it was. Tools stay installed.
  --full      Everything --configs does, plus remove the apt packages, fonts,
              the starship binary, ble.sh and the WezTerm apt repository
              that THIS installer added.
              Anything that was already present is left untouched.
              apt packages go only if removing them takes nothing else
              with them; you see the exact list and confirm first.
  --dry-run   Show what would change; touch nothing.
  --yes       Do not ask before removing apt packages.
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
        --yes|-y)   ASSUME_YES=1   ;;
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

# prune_empty_dirs <dir>...
#
# rmdir each <dir> and then its parents while they are empty, stopping at
# $HOME. Leaves ~/.config/alacritty, ~/.config/bat/themes, ~/.local/share/fonts
# etc. gone once the files we put there are. A directory that still holds
# anything (yours, or another tool's) stays.
prune_empty_dirs() {
    local d
    for d in "$@"; do
        while [[ "$d" == "$HOME"/* && -d "$d" ]]; do
            # The XDG base dirs stay even when empty: other programs expect them.
            case "$d" in
                "$HOME/.config"|"$HOME/.local"|"$HOME/.local/share"|"$HOME/.cache") break ;;
            esac
            [[ -z "$(ls -A -- "$d" 2>/dev/null)" ]] || break
            echo "  remove empty dir: $d"
            [[ $DRY_RUN -eq 1 ]] && break
            rmdir -- "$d" 2>/dev/null || break
            d="$(dirname -- "$d")"
        done
    done
}

if [[ ! -f "$MANIFEST" && -d "$PRISTINE_DIR" ]]; then
    # --full drops the manifest but keeps the pristine store, so this is what a
    # second --full (or --configs after --full) sees. Nothing left to revert.
    ok "nothing to revert - no manifest (already uninstalled?)"
    echo "   pristine copies of your originals are still in $PRISTINE_DIR"
    exit 0
fi

if [[ ! -f "$MANIFEST" ]]; then
    warn "no manifest at $MANIFEST"
    echo
    echo "This uninstaller only reverts what a manifest-writing install recorded,"
    echo "so it will not guess. If you installed before manifests existed, the"
    echo "old installer left timestamped backups next to each file:"
    echo
    for f in "$HOME/.bashrc" "$HOME/.bash_aliases" "$HOME/.blerc" "$HOME/.tmux.conf" \
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
# Remember whether bat themes are among them: bat needs its cache refreshed
# once they are gone, or it keeps listing them.
bat_themes_touched=0
file_dirs=()
jq -e '.files[] | select(.id | test("/bat/themes/"))' "$MANIFEST" >/dev/null 2>&1 &&
    bat_themes_touched=1
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
        # The parent may be gone (you deleted ~/.config/foo by hand); without
        # it cp fails and set -e would stop the uninstall halfway.
        run mkdir -p "$(dirname -- "$path")"
        run cp -a "$pristine" "$path"
    else
        warn "pristine copy missing for $path (expected $pristine) - leaving as is"
    fi
    file_dirs+=("$(dirname -- "$path")")
done < <(jq -r '.files[] | [.id, (.pristine // "null")] | @tsv' "$MANIFEST")
prune_empty_dirs "${file_dirs[@]}"

if [[ $bat_themes_touched -eq 1 ]]; then
    if [[ $DRY_RUN -eq 1 ]]; then
        printf '\033[35m  would:\033[0m %s\n' "refresh bat's theme cache"
    else
        bat_refresh_theme_cache
    fi
fi

# --- 1b. default terminal (x-terminal-emulator) ----------------------------
#
# A setting, not a tool, so --configs reverts it too: back to "auto" or to the
# terminal someone had pinned before our first install of a terminal.

while IFS=$'\t' read -r name mode value; do
    [[ -n "$name" ]] || continue
    current="$(update-alternatives --query "$name" 2>/dev/null | awk '/^Status:/ { s = $2 } /^Value:/ { v = $2 } END { print s " " v }')"
    if [[ "$mode" == manual && "$value" != null && -e "$value" ]]; then
        [[ "$current" == "manual $value" ]] && continue
        info "default terminal: back to $value ($name)"
        run sudo update-alternatives --set "$name" "$value"
    else
        [[ "$current" == auto* ]] && continue
        info "default terminal: back to automatic ($name)"
        run sudo update-alternatives --auto "$name"
    fi
done < <(jq -r '(.alternatives // [])[] | [.id, .mode, (.value // "null")] | @tsv' "$MANIFEST")

if [[ "$MODE" == "configs" ]]; then
    echo
    ok "configs reverted. Open a new terminal (or run: exec bash)."
    echo "   Tools are still installed. Use --full to remove them too."
    exit 0
fi

# --- 2. fonts --------------------------------------------------------------

info "removing fonts we installed"
# preexisting == true: the file was there before our first install - keep it.
# Entries recorded before that flag existed carry none and count as ours.
mapfile -t fonts < <(jq -r '.fonts[] | select(.preexisting != true) | .id' "$MANIFEST")
if [[ ${#fonts[@]} -eq 0 ]]; then
    echo "  (none recorded)"
else
    for f in "${fonts[@]}"; do
        if [[ -e "$f" ]]; then echo "  remove: $f"; run rm -f "$f"; fi
    done
    prune_empty_dirs "$(dirname -- "${fonts[0]}")"
    if command -v fc-cache >/dev/null 2>&1; then run fc-cache -f; fi
fi

# --- 3. standalone binaries (starship) -------------------------------------

info "removing binaries we installed"
mapfile -t bins < <(jq -r '.bins[] | select(.preexisting == false) | .id' "$MANIFEST")
if [[ ${#bins[@]} -eq 0 ]]; then
    echo "  (none - nothing installed by us, or all were pre-existing)"
else
    for b in "${bins[@]}"; do
        if [[ -e "$b" ]]; then echo "  remove: $b"; run sudo rm -f "$b"; fi
    done
fi

# --- 4. directory trees we installed (ble.sh) ------------------------------
#
# Only entries explicitly flagged preexisting=false are ours to delete. Older
# `dirs` entries carry no flag (they just note a config dir we created, whose
# contents step 1 already reverted) and are skipped.

info "removing directories we installed"
mapfile -t trees < <(jq -r '.dirs[] | select(.preexisting == false) | .id' "$MANIFEST")
if [[ ${#trees[@]} -eq 0 ]]; then
    echo "  (none recorded)"
else
    for d in "${trees[@]}"; do
        if [[ -d "$d" ]]; then echo "  remove: $d"; run rm -rf "$d"; fi
    done
fi

# --- 5. apt packages -------------------------------------------------------

#
# Never a bare `apt-get remove` + `apt-get autoremove -y`. That pair (the old
# code) removes far more than ours:
#   - `remove git` also removes everything that DEPENDS on git -- git-lfs, tig,
#     whatever you installed after us;
#   - `autoremove` removes every orphaned package on the system. On SF-WS1181
#     (2026-10-12) that was 21 NVIDIA-570 driver packages.
# So: ask apt (a simulation, -s, needs no root) what each removal would really
# take with it, skip any of ours that would drag in something that is not
# ours, and of the orphans only take those that OUR removal orphans -- never
# the ones that were orphaned already.

# apt_sim_removed <apt-get args>... -- the packages a simulated run removes.
apt_sim_removed() {
    apt-get -s "$@" 2>/dev/null | awk '$1 == "Remv" { print $2 }' | sort -u
}

info "removing apt packages we installed"
mapfile -t recorded < <(jq -r '.packages[] | select(.preexisting == false) | .id' "$MANIFEST")
pkgs=()
left=()     # ours, but still installed when we are done -- stays in the manifest
for p in "${recorded[@]}"; do
    pkg_installed "$p" && pkgs+=("$p")
done
if [[ ${#pkgs[@]} -eq 0 ]]; then
    echo "  (none - every package was already present before install, or is gone)"
else
    ours_sorted="$(printf '%s\n' "${pkgs[@]}" | sort -u)"
    keep=()
    for p in "${pkgs[@]}"; do
        extra="$(comm -23 <(apt_sim_removed remove "$p") <(echo "$ours_sorted"))"
        if [[ -n "$extra" ]]; then
            warn "keeping $p: removing it would also remove $(echo $extra)"
            left+=("$p")
        else
            keep+=("$p")
        fi
    done

    if [[ ${#keep[@]} -eq 0 ]]; then
        echo "  (nothing can go without taking other packages with it)"
    else
        # Orphans before vs after removing ours: only the difference is ours.
        orphans="$(comm -23 \
            <(apt_sim_removed remove --autoremove "${keep[@]}") \
            <({ apt_sim_removed autoremove; printf '%s\n' "${keep[@]}"; } | sort -u))"
        mapfile -t orphans < <(printf '%s' "$orphans" | sed '/^$/d')

        echo "  ours:                   ${keep[*]}"
        [[ ${#orphans[@]} -gt 0 ]] &&
            echo "  pulled in by ours only: ${orphans[*]}"

        go=1
        if [[ $DRY_RUN -eq 0 && $ASSUME_YES -eq 0 && -t 0 ]]; then
            read -r -p "  remove these $(( ${#keep[@]} + ${#orphans[@]} )) packages? [y/N] " answer
            [[ "$answer" == [yY]* ]] || go=0
        fi
        if [[ $go -eq 1 ]]; then
            run sudo apt-get remove -y "${keep[@]}" "${orphans[@]}"
        else
            warn "apt packages left installed"
            left+=("${keep[@]}")
        fi
    fi
fi

# --- 6. system files (the WezTerm apt repository) -------------------------
#
# After the packages: while wezterm-nightly is still installed (you said no,
# or something needs it) its repository stays too, so it keeps getting
# updates, and both stay in the manifest for the next --full.

info "removing system files we added"
mapfile -t sysfiles < <(jq -r '(.sysfiles // [])[] | select(.preexisting == false) | .id' "$MANIFEST")
keep_sysfiles=0
for p in "${left[@]}"; do
    [[ "$p" == wezterm* ]] && keep_sysfiles=1
done
if [[ ${#sysfiles[@]} -eq 0 ]]; then
    echo "  (none recorded)"
elif [[ $keep_sysfiles -eq 1 ]]; then
    echo "  (kept: wezterm is still installed and updates from them)"
else
    removed_source=0
    for f in "${sysfiles[@]}"; do
        if [[ -e "$f" ]]; then
            echo "  remove: $f"
            run sudo rm -f "$f"
            [[ "$f" == /etc/apt/* ]] && removed_source=1
        fi
    done
    # drop the repository's cached package lists with it
    if [[ $removed_source -eq 1 ]]; then run sudo apt-get update -qq; fi
fi

# --- 7. manifest + pristine store ------------------------------------------
#
# Keep the pristine store. If the user re-installs later we want the ORIGINAL
# originals, not a snapshot of a half-reverted state. Only drop the manifest.

if [[ ${#left[@]} -gt 0 ]]; then
    # Keep the record of the packages that are ours but stayed, so a later
    # --full (after you removed whatever needed them) can still take them.
    info "manifest keeps only the packages left installed: ${left[*]}"
    if [[ $DRY_RUN -eq 0 ]]; then
        tmp="$(mktemp)"
        jq --argjson left "$(printf '%s\n' "${left[@]}" | jq -R . | jq -s .)" \
           --argjson keep_sys "$( ((keep_sysfiles)) && echo true || echo false)" '
            .files = [] | .fonts = [] | .bins = [] | .dirs = []
            | (if $keep_sys then . else .sysfiles = [] end)
            | .packages = [.packages[] | select(.id as $id | $left | index($id))]
        ' "$MANIFEST" > "$tmp" && mv "$tmp" "$MANIFEST"
    fi
else
    info "clearing manifest"
    run rm -f "$MANIFEST"
fi
echo "  kept pristine copies in $PRISTINE_DIR (delete by hand if you are sure)"

echo
ok "full uninstall complete. Open a new terminal."
