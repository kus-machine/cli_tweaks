# Project Plan & Roadmap

**Goal:** one consistent, Ubuntu-24-style CLI experience across Linux, macOS,
Windows 11, and remote SSH targets (Raspberry Pi) — plus a clean, reworked set
of installers and a good SSH config.

_Last updated: 2026-07-12._

## Locked decisions

| # | Decision | Rationale |
|---|----------|-----------|
| 1 | **Windows = native PowerShell 7 only** (no WSL, no tmux) | Simpler; user wants a native Windows shell, not a Linux VM |
| 2 | **Alacritty on all three desktops**, one shared TOML | Maximum visual consistency, single file to maintain |
| 3 | **Remote/Pi = lightweight bash profile** (fuzzy + macros, no GUI/fonts) | Pi is headless; fast to push over SSH |
| 4 | **`shared/` holds portable configs** (starship, alacritty, ssh) | De-duplicate; platforms reference, never copy-in |
| 5 | **Adopt zoxide as canonical** and wire it everywhere | It was documented but never actually wired anywhere |

## Environment facts (this Windows machine, probed 2026-07-12)

- Windows PowerShell **5.1** only; **pwsh7 not installed**.
- Package managers: **winget ✓**, **choco ✓**, scoop ✗ → standardise on winget.
- **git ✓** present; starship/fzf/eza/zoxide/fd/rg/bat/btop/alacritty all **missing**.
- pwsh7 profile target: `~/Documents/PowerShell/profile.ps1`.

## Status board

### ✅ Done (this pass)
- Full inventory of existing Ubuntu/macOS setup.
- Repo reorganised: added `shared/`, `docs/`, `windows/`.
- Moved `alacritty.toml` + `starship.toml` → `shared/`; updated Ubuntu scripts.
- Wrote docs: README, CLAUDE.md, ARCHITECTURE, PARITY, this plan.
- **Installed & verified the full Windows stack** on Windows 11 / pwsh 7.6.3
  (2026-07-12): winget installs pwsh7 + fzf/fd/eza/zoxide/rg/bat/btop4win +
  starship + alacritty + FiraCode Nerd Font; profile loads clean; every
  macro/tool resolves. Fixes landed from testing (see gotchas below).

### Windows gotchas learned while testing
- `install.ps1` **must be ASCII-only**: it runs under Windows PowerShell 5.1,
  which reads no-BOM `.ps1` as ANSI and turns em-dashes into phantom string
  delimiters → parse failure. Kept ASCII.
- **btop's command is `btop4win`** on Windows (no `btop` shim); profile falls back.
- **PSFzf must land in pwsh7's module dir** (`Documents\PowerShell\Modules`), not
  5.1's. Script now `Save-Module`s straight there.
- pwsh7 from winget installs as the **MSIX/Store build** (alias in
  `...\WindowsApps\pwsh.exe`), not an MSI in `Program Files`.
- Piping an inline multi-line `-Command` from 5.1 into `pwsh` mangles quotes —
  avoid; ask pwsh only for single quote-free expressions.
- Profile's `PredictionSource` needs a real terminal; now gated on
  `-not [Console]::IsOutputRedirected`.

### Windows polish + uninstaller (done)
- **Alacritty launches pwsh 7**: `windows/alacritty-windows.toml` overlay
  (`[terminal.shell] program = "pwsh"`) appended to the shared config on deploy.
  Kept out of `shared/` because it would break Alacritty on Linux/macOS.
- **`-SetDefaultTerminal`** flag (in `-All`): sets Windows Terminal's default
  profile to the pwsh 7 profile; **`-SetWindowsDefaultTerminalApp`** (opt-in)
  sets the Windows system default-terminal-app to WT.
- **Install manifest** (`%LOCALAPPDATA%\cli_tweaks\install-manifest.json`)
  records packages (with a `preexisting` flag), deployed files + backups, the
  PSFzf module, fonts, and prior WT/terminal settings.
- **`windows/uninstall.ps1`** — `-Cosmetic` (configs/defaults only) and `-Full`
  (also removes tools/fonts/module we installed), `-WhatIf`, `-Yes` for pwsh7.
  Verified via dry run: it **skips packages flagged pre-existing**.
- Added `windows/README.md`.

_SSH config and the Raspberry Pi / remote profile are intentionally **plan-only**
for now (below) — nothing implemented yet._

### 📝 Next up (priority order)
1. **Windows: eyeball interactive session in a real terminal.** Installed +
   verified programmatically; Alacritty now launches pwsh7 automatically. Still
   worth opening Alacritty once to confirm the live starship prompt, the
   fzf `Ctrl+T`/`Ctrl+R`/`Alt+C` keybindings, and that opacity 0.9 renders (if it
   looks fully opaque, run the 0.6 diagnostic then restore 0.9).
2. **Add zoxide to Ubuntu** `.bashrc` (`eval "$(zoxide init bash)"`) + package.
3. **macOS rewrite to parity** (needs a Mac to test):
   - Add starship + `shared/starship.toml`.
   - eza `l`/`la`/`lss`, `tr`, `fin`; fzf + fd backend; zoxide; btop.
   - Reconcile git aliases to `gs`/`gd`/`gl`.
   - Add `macos/install.sh` (brew-based, same component model).
4. **SSH config (design + manual how-to doc; NOT auto-installed).** Cover:
   autoconnect (ControlMaster multiplexing), auto-disconnect on dead links
   (ServerAlive*), agent forwarding scoped to trusted hosts, and "connect by
   last octet" subnet macros. Ship a doc explaining how to apply it and edit the
   macros by hand — do not wire it into any installer.
5. **Raspberry Pi / remote profile.** Lightweight bash (fuzzy + macros, optional
   starship), no GUI/fonts; a way to push it over SSH. Validate on real hardware.
6. **Consider `shared/tmux.conf`** (merge the two near-identical copies).

### 💡 Backlog / nice-to-have
- `bat` theme aligned with Tokyo Night (matches alacritty).
- Windows Terminal profile as an alternative GUI (decision was Alacritty, but
  WT integrates well — optional).
- A top-level cross-platform `bootstrap` doc / one-liner per OS.
- Neovim config if the user adopts an editor beyond nano.
- CI check that `shared/` files stay valid TOML.

## Per-want traceability (original request)

1. **macOS + Windows close to Ubuntu** → PARITY.md matrix; Windows drafted,
   macOS planned (step 3).
2. **Rework install scripts** → componentised model kept; `shared/` removes
   duplication; Windows installer added; macOS installer planned.
3. **SSH config** → planned (step 4). Manual how-to doc, **not** auto-installed:
   autoconnect (ControlMaster), auto-disconnect (ServerAlive*), scoped agent
   forwarding, last-octet subnet macro.
4. **rpi SSH experience** → planned (step 5): lightweight bash profile
   (fuzzy + macros), no GUI/fonts.
