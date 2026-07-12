# Windows 11 — native PowerShell 7 setup

Reproduces the Ubuntu 24 CLI experience in **native PowerShell 7** (no WSL):
starship prompt, fzf fuzzy search, eza, zoxide, the macros, Alacritty, and the
FiraCode Nerd Font. Everything installs **per-user** via winget.

## Install

Run the first time from **Windows PowerShell 5.1** (it bootstraps pwsh 7):

```powershell
cd windows
./install.ps1 -All
```

`-All` installs everything **and** sets Windows Terminal's default profile to
PowerShell 7. It does **not** change the Windows system "Default terminal
application" — that stays opt-in (see below).

### Component flags

| Flag | Does |
|------|------|
| `-Shell` | Install PowerShell 7 (`Microsoft.PowerShell`) |
| `-Packages` | fzf, fd, eza, zoxide, ripgrep, bat, btop4win + the PSFzf module (into pwsh7's scope) |
| `-Fonts` | FiraCode Nerd Font (per-user) |
| `-Starship` | starship + `shared/starship.toml` → `~/.config` |
| `-Configs` | the pwsh 7 profile → `~/Documents/PowerShell/profile.ps1` |
| `-Alacritty` | Alacritty + `shared/alacritty.toml` **plus** the pwsh-shell overlay |
| `-SetDefaultTerminal` | Windows Terminal default profile → PowerShell 7 (included in `-All`) |
| `-SetWindowsDefaultTerminalApp` | Opt-in: set the Windows "Default terminal application" to Windows Terminal (**not** in `-All`) |

Mix freely, e.g. `./install.ps1 -Shell -Packages -Starship -Configs -Alacritty`.

Existing files are backed up to `*.bak.<timestamp>` before being replaced, and
everything the installer does is recorded in a manifest (see below).

## After installing

1. **Open a new pwsh 7 session** (the PowerShell 7 icon / a fresh terminal —
   not an already-open Windows PowerShell 5.1 window). You should see the
   starship prompt and the macros (`l`, `gs`, `z`, fzf `Ctrl+T`/`Ctrl+R`/`Alt+C`).
2. **Alacritty** now launches pwsh 7 automatically (via the overlay), so "Open
   in Alacritty" gives you the full profile. If `pwsh` isn't found, edit the
   `[terminal.shell] program` in `%APPDATA%\alacritty\alacritty.toml` to the full
   `pwsh.exe` path.

### Manual system settings (intentionally not fully automated)

- **Windows "Default terminal application"** (Settings → Privacy & security →
  For developers, or Windows Terminal → Settings → Startup). `-All` leaves this
  alone; pass `-SetWindowsDefaultTerminalApp` to point it at Windows Terminal.
- The **"Open in PowerShell 7 here"** context menu is a Windows/PowerShell
  feature, not something this repo installs.

## Uninstall

```powershell
./uninstall.ps1 -Cosmetic          # revert configs + WT/terminal defaults; keep tools
./uninstall.ps1 -Full              # cosmetic + remove the tools/fonts/module WE installed
./uninstall.ps1 -Full -WhatIf      # dry run: show exactly what would happen
./uninstall.ps1 -Full -Yes         # also remove PowerShell 7 itself
```

It is driven by the manifest and **never removes anything that was already
installed before** (those are flagged `preexisting` and skipped). Config files
are restored from their backups; if no backup existed, our file is removed.
Always try `-WhatIf` first.

## How it stays safe (the manifest)

`install.ps1` writes `%LOCALAPPDATA%\cli_tweaks\install-manifest.json` recording:

- which winget packages it installed, and whether each was **already present**
  (pre-existing packages are never uninstalled);
- every config file it deployed and the path of the backup it took;
- the PSFzf module location and the font files/registry values it added;
- the previous Windows Terminal default profile and Windows default-terminal-app
  values, so they can be restored exactly.

## Gotchas (learned during bring-up)

- `install.ps1` / `uninstall.ps1` are **ASCII-only** on purpose: they run under
  Windows PowerShell 5.1, which reads a no-BOM `.ps1` as ANSI and turns
  em-dashes/smart quotes into phantom string delimiters that break parsing.
- **btop's command is `btop4win`** on Windows (no `btop` shim); the profile
  falls back to it.
- winget installs pwsh 7 as the **MSIX/Store build** (alias in
  `…\WindowsApps\pwsh.exe`), not an MSI under `Program Files`.
