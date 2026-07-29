#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# ble.sh (Bash Line Editor) - gives bash the fish-style grey inline suggestion
# while you type, which plain readline cannot do.
#
# There is no `blesh` apt package on Ubuntu 24.04, so we take upstream's
# prebuilt nightly tarball. That is the no-build install path: a source install
# would additionally need gawk + make, and the last tagged release (v0.4.0-devel3)
# is from 2023 and predates the fzf/starship integrations we rely on.
#
# Everything lands in one directory ($BLESH_DIR), which is what the manifest
# records, so uninstall --full can drop it in one move.
# ---------------------------------------------------------------------------
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/common.sh"

BLESH_DIR="$HOME/.local/share/blesh"
BLESH_URL="https://github.com/akinomyoga/ble.sh/releases/download/nightly/ble-nightly.tar.xz"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

apt_install_tracked curl

manifest_init

# Did WE put it there? If the directory exists and the manifest does not say it
# is ours, it is the user's own ble.sh - leave it completely alone, exactly like
# install-starship.sh does with a pre-existing starship.
if [[ -e "$BLESH_DIR" ]] &&
   ! jq -e --arg id "$BLESH_DIR" \
        '.dirs[]? | select(.id == $id and .preexisting == false)' \
        "$MANIFEST" >/dev/null 2>&1; then
    ok "ble.sh already present at $BLESH_DIR - leaving it alone"
    record_dir "$BLESH_DIR" true
else
    info "downloading ble.sh (nightly)"
    curl -fsSL --retry 2 -o "$TMP_DIR/ble-nightly.tar.xz" "$BLESH_URL"

    tar xJf "$TMP_DIR/ble-nightly.tar.xz" -C "$TMP_DIR"

    # The tarball unpacks into ble-nightly/ (dated names appear on some
    # mirrors), so glob rather than hard-code the directory name.
    shopt -s nullglob
    sources=("$TMP_DIR"/ble-*/ble.sh)
    shopt -u nullglob
    [[ ${#sources[@]} -gt 0 ]] || die "unexpected ble.sh tarball layout in $TMP_DIR"

    info "installing into $BLESH_DIR"
    # ble.sh installs itself: --install takes the PARENT dir and creates blesh/
    bash "${sources[0]}" --install "$HOME/.local/share" >/dev/null

    [[ -s "$BLESH_DIR/ble.sh" ]] || die "ble.sh install did not produce $BLESH_DIR/ble.sh"
    record_dir "$BLESH_DIR" false
    # ble.sh builds terminfo/keymap caches here on first attach. It exists only
    # because of the install above, so uninstall --full may drop it too.
    record_dir "$HOME/.cache/blesh" false
fi

echo
ok "ble.sh installed"
echo "   ./install.sh --configs wires it into ~/.bashrc (source + attach)"
echo "   suggestions come from your history: Right/End accepts, Ctrl+Right takes one word"
