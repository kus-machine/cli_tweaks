#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# cli_tweaks - shared helpers for the Ubuntu installers.
#
# Everything an installer touches is recorded in a manifest so that
# ./uninstall.sh can put the machine back the way it found it:
#
#   $STATE_DIR/install-manifest.json   what we did
#   $STATE_DIR/pristine/               byte-for-byte copies of YOUR original
#                                      dotfiles, captured on the FIRST install
#                                      and never overwritten afterwards
#
# The "capture once" rule matters. The old helper did `mv file file.bak.<ts>`
# on every run, so re-running the installer buried the real original under a
# pile of backups-of-our-own-config and there was no way to tell which one was
# pristine.
# ---------------------------------------------------------------------------

set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/cli_tweaks"
MANIFEST="$STATE_DIR/install-manifest.json"
PRISTINE_DIR="$STATE_DIR/pristine"

# --- pretty output ---------------------------------------------------------

info()  { printf '\033[36m==>\033[0m %s\n' "$*"; }
ok()    { printf '\033[32m  ok\033[0m %s\n' "$*"; }
warn()  { printf '\033[33m  !!\033[0m %s\n' "$*" >&2; }
die()   { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }

# --- prerequisites ---------------------------------------------------------

# jq is how we read/write the manifest. It is small and not installed by
# default on Ubuntu 24 Desktop, so bootstrap it before anything else.
ensure_jq() {
    command -v jq >/dev/null 2>&1 && return 0
    info "installing jq (needed to track what this installer changes)"
    sudo apt-get install -y jq >/dev/null
}

# --- manifest --------------------------------------------------------------

manifest_init() {
    ensure_jq
    mkdir -p "$STATE_DIR" "$PRISTINE_DIR"
    [[ -f "$MANIFEST" ]] && return 0

    jq -n --arg now "$(date -Is)" '{
        version:    1,
        created_at: $now,
        updated_at: $now,
        files:      [],
        packages:   [],
        fonts:      [],
        bins:       [],
        dirs:       []
    }' > "$MANIFEST"
}

# manifest_add <key> <json-object>
# Idempotent: an entry with the same .id replaces the previous one.
manifest_add() {
    local key="$1" obj="$2" tmp
    manifest_init
    tmp="$(mktemp)"
    jq --arg key "$key" --argjson obj "$obj" --arg now "$(date -Is)" '
        .updated_at = $now
        | .[$key] = ((.[$key] // []) | map(select(.id != $obj.id)) + [$obj])
    ' "$MANIFEST" > "$tmp"
    mv "$tmp" "$MANIFEST"
}

# --- files -----------------------------------------------------------------

# deploy_file <src> <dst>
#
# Captures <dst> into the pristine store the first time we ever touch it, then
# installs <src> over it. Re-runs do NOT create extra backups: the pristine
# copy already holds your original.
deploy_file() {
    local src="$1" dst="$2"
    local rel pristine

    [[ -f "$src" ]] || die "source config missing: $src"
    manifest_init

    # Stable, collision-free name for the pristine copy: the path relative to
    # $HOME with slashes flattened, e.g. .config_alacritty_alacritty.toml
    rel="${dst#"$HOME/"}"
    pristine="$PRISTINE_DIR/${rel//\//_}"

    # Have we recorded this path before? If so, keep the pristine value exactly
    # as first recorded -- including a recorded "there was nothing here". Going
    # by "does the file exist" instead would, on the second run, capture OUR
    # OWN deployed config as if it were the user's original.
    if jq -e --arg id "$dst" '.files[]? | select(.id == $id)' "$MANIFEST" >/dev/null 2>&1; then
        pristine="$(jq -r --arg id "$dst" \
            '.files[] | select(.id == $id) | (.pristine // "")' "$MANIFEST")"
    elif [[ -e "$dst" ]]; then
        cp -a "$dst" "$pristine"
        # Also leave the familiar timestamped backup beside the file, once.
        cp -a "$dst" "${dst}.bak.$(date +%Y%m%d_%H%M%S)"
        info "captured original $dst -> $pristine"
    else
        # Nothing was there: record that, so uninstall removes our file rather
        # than restoring a file that never existed.
        pristine=""
    fi

    mkdir -p "$(dirname "$dst")"
    install -m 644 "$src" "$dst"
    manifest_add files "$(jq -n --arg id "$dst" --arg p "$pristine" \
        '{id: $id, pristine: (if $p == "" then null else $p end)}')"
    ok "$dst"
}

# --- packages --------------------------------------------------------------

pkg_installed() {
    [[ "$(dpkg-query -W -f='${db:Status-Status}' "$1" 2>/dev/null || true)" == "installed" ]]
}

# apt_install_tracked <pkg>...
#
# Records whether each package was ALREADY present, so the uninstaller can
# remove only what we actually added.
apt_install_tracked() {
    local pkg pre
    local to_install=()

    manifest_init
    for pkg in "$@"; do
        if pkg_installed "$pkg"; then
            pre=true
        else
            pre=false
            to_install+=("$pkg")
        fi
        manifest_add packages "$(jq -n --arg id "$pkg" --argjson pre "$pre" \
            '{id: $id, manager: "apt", preexisting: $pre}')"
    done

    if [[ ${#to_install[@]} -eq 0 ]]; then
        ok "already present: $*"
        return 0
    fi

    info "apt install: ${to_install[*]}"
    sudo apt-get install -y "${to_install[@]}"
}

# --- fonts / standalone binaries / dirs ------------------------------------

record_font() {
    manifest_add fonts "$(jq -n --arg id "$1" '{id: $id}')"
}

# record_bin <path> <preexisting:true|false>
record_bin() {
    manifest_add bins "$(jq -n --arg id "$1" --argjson pre "$2" \
        '{id: $id, preexisting: $pre}')"
}

# record_dir <path> [preexisting:true|false]
#
# Without the flag the entry is only a note that we created the directory, and
# the uninstaller leaves it alone (e.g. ~/.config/alacritty, whose *contents*
# are reverted file by file). With preexisting=false it means "this whole tree
# is ours" (e.g. ~/.local/share/blesh) and --full deletes it.
record_dir() {
    local pre="${2:-}"
    if [[ -n "$pre" ]]; then
        manifest_add dirs "$(jq -n --arg id "$1" --argjson pre "$pre" \
            '{id: $id, preexisting: $pre}')"
    else
        manifest_add dirs "$(jq -n --arg id "$1" '{id: $id}')"
    fi
}
