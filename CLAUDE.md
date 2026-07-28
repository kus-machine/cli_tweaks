# CLAUDE.md

Guide for AI assistants (and future-me) working in this repo.

## What this repo is

Personal, single-user dotfiles/CLI setup. The **goal** is one consistent
Ubuntu-24-style terminal experience across Linux, macOS, and Windows 11 (native
PowerShell 7). A lightweight remote SSH profile (Raspberry Pi) is a planned
future target — see [docs/PLAN.md](docs/PLAN.md).

Read these first: [docs/PLAN.md](docs/PLAN.md) (roadmap + status + decisions),
[docs/PARITY.md](docs/PARITY.md) (canonical feature matrix),
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) (layout + principles).

## Golden rules

1. **Ubuntu24 is the canonical experience.** When adding a feature, define it in
   the Ubuntu configs + PARITY.md first, then propagate to other platforms.
2. **Portable configs live in `shared/`** (starship, alacritty). Platform
   installers *reference* them; never copy a shared file into a platform folder.
   If you change where a shared file lives, update every installer that reads it
   (currently: `Ubuntu24/scripts/install-{starship,alacritty}.sh`,
   `windows/install.ps1`).
3. **Per-shell files stay platform-local** because syntax differs:
   `Ubuntu24/configs/.bashrc` + `.bash_aliases` (bash), `macos/.zshrc` (zsh),
   `windows/Microsoft.PowerShell_profile.ps1` (pwsh).
4. **Guard every tool** behind a presence check (`command -v` / `Get-Command`)
   so partial installs never break the shell.
5. **Never overwrite a user file without capturing the original first**, and
   capture it **once**. Use `deploy_file` in `Ubuntu24/scripts/common.sh` (or
   `Backup-File` in `install.ps1`) — never a bare `install`/`cp`. `deploy_file`
   snapshots the original into `~/.local/state/cli_tweaks/pristine/` on the
   first install only, and keys that decision off the *manifest*, not off
   "does the file exist" — otherwise a second run captures our own config as if
   it were the user's original. (The pre-2026-07 `backup_file` helper did
   `mv file file.bak.<ts>` on every run and destroyed the real original.)
6. Keep installers **componentised** with matching switches across platforms:
   `packages`, `fonts`, `starship`, `configs`, `alacritty` (+ `shell` on
   Windows for pwsh7). SSH is a planned, separate, manual step — not auto-installed.
7. **Every install component must be revertible.** Record what it did in the
   manifest and undo it in the platform uninstaller
   (`Ubuntu24/uninstall.sh`, `windows/uninstall.ps1`). Both refuse to touch
   anything flagged `preexisting`.

## Keep parity in sync

The same alias/function set must exist in all four shells. When you touch one,
touch the others (or explicitly note the gap in PARITY.md):

- `l` / `la` / `lss` (eza), `tr` (tree fn), `fin` (find), `c` (clear)
- `gs` / `gd` / `gl` (git), `top`/`htop` → btop
- fzf keybindings with an fd backend; UP/DOWN prefix history search
- zoxide `z` (canonical, still being rolled out — see PARITY drift notes)
- tmux helpers `t`/`ta`/`tk`/`tn` on Linux/macOS only (Windows has no tmux)

## Environment / tooling gotchas

- There are **two dev machines**. Check which one you are on before trusting
  the notes below.
  - **Ubuntu 24** (`SF-WS1181`): full coreutils, normal bash. Ubuntu changes
    can be tested here for real.
  - **Windows 11**: the **Bash tool there lacks coreutils** (`find`, `mkdir`,
    `echo` fail) — use PowerShell or the dedicated file tools for filesystem
    work, not `bash -c`.
- **Bash `Tab` completion is order-sensitive**: `bash-completion` must be
  sourced *before* fzf's `completion.bash`. fzf hijacks ~35 commands and its
  fallback to the real completion only arms itself if `_completion_loader`
  already exists. Get it wrong and Tab dies in Alacritty/GNOME Terminal but
  keeps working in tmux (tmux starts a login shell, which loads
  bash-completion via `/etc/profile.d/` first). See `Ubuntu24/configs/.bashrc`.
- **Alacritty needs working OpenGL/GLX.** A `BadValue … BadAttribute` startup
  error is a GPU-driver fault, not a config fault — check `glxinfo -B` and
  `nvidia-smi` (a driver upgrade needs a reboot before the kernel module
  matches the userspace libs). Don't debug the TOML for this.
- Windows has **only Windows PowerShell 5.1** so far; pwsh7 is installed by
  `windows/install.ps1 -Shell`. The pwsh7 profile path is
  `~/Documents/PowerShell/profile.ps1` (NOT the `WindowsPowerShell` 5.1 path).
- Package manager on Windows: **winget** (choco also present; scoop absent).
  All winget IDs used are verified to exist; btop = `aristocratos.btop4win`
  (its command is `btop4win`, no `btop` shim).
- **`windows/install.ps1` and `uninstall.ps1` must stay ASCII-only** — they run
  under Windows PowerShell 5.1, which reads a no-BOM `.ps1` as ANSI and turns
  em-dashes/smart quotes into phantom string delimiters that break parsing. The
  pwsh7 **profile** may use non-ASCII (pwsh reads UTF-8).
- **Install writes a manifest** (`%LOCALAPPDATA%\cli_tweaks\install-manifest.json`)
  recording packages (+ `preexisting` flag), deployed files + backups, module,
  fonts, and prior WT/terminal settings. `uninstall.ps1` reverts from it and
  **never removes anything flagged pre-existing**. Keep both in sync when you add
  an install component: record what it does in the manifest, revert it in uninstall.
- Alacritty's pwsh shell lives in `windows/alacritty-windows.toml` (overlay
  appended on deploy), NOT in `shared/alacritty.toml` (that would break Linux/macOS).

## Testing notes

- Windows changes can be tested on this machine (with the user's OK before
  installing software).
- macOS (and any future remote-hardware work) **cannot** be tested here — mark
  such changes as draft and call out that they need real-hardware validation.

## Style

Match the existing config style: heavy explanatory comments, clear section
banners, defensive guards. These are read by a human tweaking their own setup,
so readability beats cleverness.
