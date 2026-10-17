#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# WezTerm - Ubuntu's terminal (./install.sh --wezterm). Until 2026-10-18 it
# was the alternative to Alacritty + tmux (now legacy/alacritty/).
#
# WezTerm has tabs and panes built in and takes the same keys as our tmux
# (Alt+1..9, Alt+T, Ctrl+B | ...), exactly like on Windows -- one config for
# both: shared/wezterm.lua. tmux stays installed (ssh, detach); WezTerm just
# does not start it.
#
# Ubuntu has no wezterm package, so this adds upstream's apt repository
# (https://wezterm.org/install/linux.html) and installs the NIGHTLY, the same
# channel as on Windows -- the last stable release is from 2024-02. Updates
# then come with the normal `sudo apt upgrade`.
#
# Both system files the repository needs are recorded BEFORE they are written
# (CLAUDE.md rule 5a), so uninstall --full removes them again -- unless they
# were already there.
# ---------------------------------------------------------------------------
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT_DIR/.." && pwd)"
source "$ROOT_DIR/scripts/common.sh"

KEYRING="/usr/share/keyrings/wezterm-fury.gpg"
SOURCES="/etc/apt/sources.list.d/wezterm.list"
REPO_URL="https://apt.fury.io/wez/"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

if pkg_installed wezterm || pkg_installed wezterm-nightly; then
    # Yours (or ours from an earlier run): apt_install_tracked keeps whatever
    # the manifest already says. Stable and nightly conflict, so never add
    # the other one next to it.
    for p in wezterm wezterm-nightly; do
        pkg_installed "$p" && apt_install_tracked "$p"
    done
else
    apt_install_tracked curl gpg

    record_sysfile "$KEYRING"
    if [[ ! -s "$KEYRING" ]]; then
        info "adding the WezTerm apt key"
        curl -fsSL --retry 2 -o "$TMP_DIR/gpg.key" "${REPO_URL}gpg.key"
        # --homedir: --dearmor needs no keyring, but gpg would still create
        # ~/.gnupg for it.
        gpg --homedir "$TMP_DIR" --dearmor < "$TMP_DIR/gpg.key" > "$TMP_DIR/wezterm-fury.gpg"
        sudo install -m 644 "$TMP_DIR/wezterm-fury.gpg" "$KEYRING"
    fi

    record_sysfile "$SOURCES"
    if [[ ! -s "$SOURCES" ]]; then
        info "adding the WezTerm apt repository ($REPO_URL)"
        echo "deb [signed-by=$KEYRING] $REPO_URL * *" > "$TMP_DIR/wezterm.list"
        sudo install -m 644 "$TMP_DIR/wezterm.list" "$SOURCES"
    fi

    info "refreshing apt package lists"
    sudo apt-get update
    apt_install_tracked wezterm-nightly
fi

# shared/wezterm.lua is the same file Windows uses (see its header).
deploy_file "$REPO_ROOT/shared/wezterm.lua" "$HOME/.config/wezterm/wezterm.lua"

# WezTerm draws with the GPU (OpenGL here). If it fails with a GLX/EGL error,
# see the GPU-driver note in CLAUDE.md -- a driver fault, not a config fault.
echo
ok "wezterm installed"
echo "   start it from the app menu (WezTerm) or with: wezterm"
