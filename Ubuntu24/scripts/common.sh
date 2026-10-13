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
#
# jq is needed to WRITE the manifest, so it cannot be recorded before it is
# installed. Instead it is noted here and manifest_init records it as ours
# (preexisting=false) right after, so uninstall --full can remove it again.
CT_JQ_BOOTSTRAPPED=0
ensure_jq() {
    command -v jq >/dev/null 2>&1 && return 0
    info "installing jq (needed to track what this installer changes)"
    # On a fresh image the package lists may be empty; --fonts or --configs
    # alone never run install-packages.sh's `apt-get update`.
    sudo apt-get install -y jq >/dev/null ||
        { sudo apt-get update >/dev/null && sudo apt-get install -y jq >/dev/null; }
    CT_JQ_BOOTSTRAPPED=1
}

# --- manifest --------------------------------------------------------------

manifest_init() {
    ensure_jq
    mkdir -p "$STATE_DIR" "$PRISTINE_DIR"
    if [[ ! -f "$MANIFEST" ]]; then
        _manifest_create
    fi
    if [[ $CT_JQ_BOOTSTRAPPED -eq 1 ]]; then
        CT_JQ_BOOTSTRAPPED=0
        manifest_has packages jq ||
            manifest_add packages '{"id": "jq", "manager": "apt", "preexisting": false}'
    fi
}

_manifest_create() {
    jq -n --arg now "$(date -Is)" '{
        version:    1,
        created_at: $now,
        updated_at: $now,
        files:      [],
        packages:   [],
        fonts:      [],
        bins:       [],
        dirs:       [],
        sysfiles:   [],
        alternatives: []
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

# manifest_has <key> <id>  -- true if an entry with that .id is already recorded.
manifest_has() {
    [[ -f "$MANIFEST" ]] &&
        jq -e --arg key "$1" --arg id "$2" \
            '(.[$key] // [])[] | select(.id == $id)' "$MANIFEST" >/dev/null 2>&1
}

# --- files -----------------------------------------------------------------

# oldest_backup_of <path>
#
# Prints the oldest backup an EARLIER installer left beside <path>
# (<path>.bak or <path>.bak.<timestamp>), or nothing. "Oldest" is by mtime,
# which `cp -a`/`mv` carry over from the file that was backed up.
oldest_backup_of() {
    local path="$1" b
    local baks=()
    # -e filter rather than nullglob: "$path".bak is a plain word, not a glob,
    # and an unmatched "$path".bak.* stays literal - neither may get through.
    for b in "$path".bak "$path".bak.*; do
        [[ -e "$b" ]] && baks+=("$b")
    done
    [[ ${#baks[@]} -gt 0 ]] || return 0
    ls -1tr -- "${baks[@]}" 2>/dev/null | head -n 1
}

# deploy_file <src> <dst>
#
# Captures <dst> into the pristine store the first time we ever touch it, then
# installs <src> over it. Re-runs do NOT create extra backups: the pristine
# copy already holds your original.
deploy_file() {
    local src="$1" dst="$2"
    local rel pristine legacy

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
    elif [[ -e "$dst" && -f "$pristine" ]]; then
        # Not in the manifest, but the pristine store already has this file:
        # an uninstall --full ran (it drops the manifest, keeps the store) and
        # you are installing again. Never overwrite the store's copy -- unless
        # the file has changed since, then THAT is your newer original, and
        # the old copy is kept beside it.
        # (A file identical to the repo's is our own deploy, not an original.)
        if ! cmp -s "$dst" "$pristine" && ! cmp -s "$dst" "$src"; then
            mv "$pristine" "${pristine}.prev.$(date +%Y%m%d_%H%M%S)"
            cp -a "$dst" "$pristine"
            info "captured changed original $dst -> $pristine (older copy kept as .prev.*)"
        fi
    elif [[ -e "$dst" ]]; then
        # Not in the manifest, but a pre-manifest installer may have run here
        # already: then $dst is an OLD cli_tweaks deploy, and your real
        # original is the oldest .bak it left behind. Prefer that one.
        legacy="$(oldest_backup_of "$dst")"
        if [[ -n "$legacy" ]]; then
            cp -a "$legacy" "$pristine"
            warn "$dst has an older installer's backup beside it -"
            warn "  treating $legacy as your original (the current file is"
            warn "  most likely an earlier cli_tweaks deploy; it is kept as .bak.<now>)"
        else
            cp -a "$dst" "$pristine"
        fi
        # Also leave the familiar timestamped backup beside the file, once.
        cp -a "$dst" "${dst}.bak.$(date +%Y%m%d_%H%M%S)"
        info "captured original ${legacy:-$dst} -> $pristine"
    else
        # Nothing was there: record that, so uninstall removes our file rather
        # than restoring a file that never existed.
        pristine=""
    fi

    # Record BEFORE installing (CLAUDE.md rule 5a): interrupted after this
    # line, the next run finds the entry and keeps the pristine value; the
    # other way round it would capture OUR file as your original.
    manifest_add files "$(jq -n --arg id "$dst" --arg p "$pristine" \
        '{id: $id, pristine: (if $p == "" then null else $p end)}')"
    mkdir -p "$(dirname "$dst")"
    install -m 644 "$src" "$dst"
    ok "$dst"
}

# --- bat -------------------------------------------------------------------

# bat_cmd -- prints the bat binary; Ubuntu's package names it `batcat`.
bat_cmd() {
    command -v batcat 2>/dev/null || command -v bat 2>/dev/null
}

# bat_refresh_theme_cache
#
# bat only sees the themes in ~/.config/bat/themes after `bat cache --build`.
# When none is left there (after uninstall), clear the cache instead, so bat
# is back on its built-in themes exactly as before.
bat_refresh_theme_cache() {
    local bat dir
    if ! bat="$(bat_cmd)"; then
        warn "bat is not installed - its theme cache was not rebuilt"
        warn "  (./install.sh --packages, then --configs again)"
        return 0
    fi
    dir="$("$bat" --config-dir)/themes"
    if compgen -G "$dir/*.tmTheme" >/dev/null; then
        "$bat" cache --build >/dev/null && ok "bat theme cache rebuilt"
    else
        "$bat" cache --clear >/dev/null && ok "bat theme cache cleared"
    fi
}

# --- packages --------------------------------------------------------------

pkg_installed() {
    [[ "$(dpkg-query -W -f='${db:Status-Status}' "$1" 2>/dev/null || true)" == "installed" ]]
}

# apt_install_tracked <pkg>...
#
# Records whether each package was ALREADY present, so the uninstaller can
# remove only what we actually added.
#
# "Present now" must not overwrite an earlier record: on a re-run, a package WE
# installed last time is installed now too, and recording it as preexisting
# would mean uninstall --full never removes it. So an installed package keeps
# whatever the manifest already says; only a package we are about to install
# right now is (re)recorded as ours.
apt_install_tracked() {
    local pkg pre
    local to_install=()

    manifest_init
    for pkg in "$@"; do
        if pkg_installed "$pkg"; then
            manifest_has packages "$pkg" && continue
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

# record_font <path> <preexisting:true|false>
#
# A font file that was already there before our first install is flagged
# preexisting and uninstall --full leaves it alone, even though the install
# refreshes its contents. The first record wins, like everywhere else.
record_font() {
    manifest_has fonts "$1" && return 0
    manifest_add fonts "$(jq -n --arg id "$1" --argjson pre "$2" \
        '{id: $id, preexisting: $pre}')"
}

# record_bin <path> <preexisting:true|false>
#
# Same rule as apt_install_tracked: "it is there now" (true) never overwrites
# an existing record -- that binary may well be the one we installed last run.
record_bin() {
    if [[ "$2" == true ]] && manifest_has bins "$1"; then
        return 0
    fi
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

# record_sysfile <path>
#
# A system file outside $HOME that an installer writes with sudo (an apt
# source, a keyring). Call it BEFORE writing: a file already there is
# preexisting and uninstall --full leaves it; one that is not is ours to
# delete. The first record wins, so on a re-run our own file stays ours.
record_sysfile() {
    local pre=false
    manifest_has sysfiles "$1" && return 0
    [[ -e "$1" ]] && pre=true
    manifest_add sysfiles "$(jq -n --arg id "$1" --argjson pre "$pre" \
        '{id: $id, preexisting: $pre}')"
}

# record_alternative <name>
#
# Remembers how a Debian alternative (update-alternatives) was set BEFORE we
# first touched it: "auto" (the highest priority wins) or "manual" + the path
# someone pinned. Call it BEFORE `update-alternatives --set`. The first record
# wins -- on a re-run the current value is our own choice, not the original.
record_alternative() {
    local name="$1" mode value
    manifest_has alternatives "$name" && return 0
    mode="$(update-alternatives --query "$name" 2>/dev/null | awk '/^Status:/ { print $2 }')"
    value="$(update-alternatives --query "$name" 2>/dev/null | awk '/^Value:/ { print $2 }')"
    manifest_add alternatives "$(jq -n --arg id "$name" --arg m "${mode:-auto}" --arg v "$value" \
        '{id: $id, mode: $m, value: (if $v == "" then null else $v end)}')"
}
