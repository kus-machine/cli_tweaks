# Windows 11 — native PowerShell 7 + WezTerm

Reproduces the Ubuntu 24 CLI experience in **native PowerShell 7** (no WSL):
starship prompt, fzf fuzzy search with previews, eza, zoxide, bat, tldr + F1,
the macros, the startup banner and the `keys` cheatsheet — in **WezTerm**,
whose built-in tabs and panes take the place of Alacritty + tmux, with the
same keys. FiraCode Nerd Font. Everything installs **per-user** via winget.

> **Status (2026-10-12):** every piece was hand-tested in a side-by-side trial
> (portable binaries, separate profile), then ported here. `install.ps1` /
> `uninstall.ps1` themselves have **not been run end-to-end yet** — see
> [docs/REMINDERS.md](../docs/REMINDERS.md).

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
| `-Packages` | fzf, fd, eza, zoxide, ripgrep, bat, btop4win, tealdeer (`tldr`, + `tldr --update`) and the PSFzf module (fzf keys) into pwsh7's scope |
| `-Fonts` | FiraCode Nerd Font (per-user) |
| `-Starship` | starship + `shared/starship.toml` → `~/.config/starship.toml` |
| `-Configs` | the pwsh 7 profile → `~/Documents/PowerShell/profile.ps1`; `keys.txt` + `shared/lesskey` → `~/.config/cli_tweaks/`; `shared/bat/themes` → `%APPDATA%\bat\themes` + `bat cache --build` |
| `-WezTerm` | WezTerm (nightly, `wez.wezterm.nightly`) + `shared/wezterm.lua` → `~/.config/wezterm/wezterm.lua` |
| `-SetDefaultTerminal` | Windows Terminal default profile → PowerShell 7 (included in `-All`) |
| `-SetWindowsDefaultTerminalApp` | Opt-in: set the Windows "Default terminal application" to Windows Terminal (**not** in `-All`; WezTerm cannot fill that role) |

Mix freely, e.g. `./install.ps1 -Shell -Packages -Starship -Configs -WezTerm`.
Order matters only for `-Configs`: run it after `-Packages` so `bat cache
--build` finds bat (or re-run `-Configs`).

An existing file is moved to `*.bak.<timestamp>` the **first** time it is
replaced (re-runs just overwrite our own copy, no new backups), and everything
the installer does is recorded in a manifest (see below) **before** it does it
— written even if a component fails halfway.

## After installing

Start **WezTerm** (Start menu). You get pwsh 7 with the full profile and the
cat banner; type `keys` or press **Ctrl+B ?** for every command and hotkey.
The headline keys:

| | |
|---|---|
| `Alt+T` `Alt+K` `Alt+1…9` `Alt+N` | new tab · close tab · go to tab · rename |
| `Alt+\` `Alt+-` `Alt+←↑→↓` `Alt+Z` `Alt+X` | split right · below · move · zoom · close pane |
| `Ctrl+B` then `\|` `-` `z` `x` `w` … | the same, tmux-style (5 s to press the key) |
| `Ctrl+C` / `Ctrl+V` | copy if something is selected (else interrupt) / paste |
| `Ctrl+B y` · `Ctrl+B Space` | copy the last command's output · pick a hash/path/URL to copy |
| `Ctrl+T` `Ctrl+R` `Alt+C` | fzf: file · history · cd (first press loads PSFzf, ~0.5 s) |
| `F1` | tldr examples for the command being typed |

**No `Ctrl+Shift+…` bindings:** Ctrl+Shift switches the keyboard layout on the
owner's machine. All WezTerm keys use **physical key positions**, so they work
on the Ukrainian layout too; `less` (git log, `keys`) gets Ukrainian twins of
its keys from `shared/lesskey`.

**Startup time:** ~0.2 s for the profile on top of pwsh's ~0.2 s (the first
Windows setup took ~5 s). Check with `$env:CLI_TWEAKS_TIMING=1; pwsh`.

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
installed before** — packages, the PSFzf module, font files and data dirs are
all flagged `preexisting` and skipped. Config files are restored from their
backups; if no original existed, our file is removed. Each reverted entry is
dropped from the manifest, so it is safe to run twice.

What `-Full` learned from the 2026-10-11 hand cleanup:

- **MSI packages** (starship, …) fail a silent uninstall without admin rights
  (exit 1603) → retried once through an elevated winget (UAC prompt).
- Success is checked with `winget list`, not trusted from the exit code; a
  package that is still there stays in the manifest, the manifest stays, and
  the script exits 1 so you can re-run it.
- winget leaves **dead user-PATH entries** (`…\WinGet\Packages\<id>…`) behind →
  removed (only ones whose folder is gone; the registry value type is kept).
- bat's theme cache, tldr's pages, the profile's init cache and WezTerm's
  `~\.local\share\wezterm` (if it did not exist before) are cleaned up too.

Without a manifest it only lists the known config paths and exits with code 1.
Always try `-WhatIf` first.

## How it stays safe (the manifest)

`install.ps1` writes `%LOCALAPPDATA%\cli_tweaks\install-manifest.json` recording:

- which winget packages it installed, and whether each was **already present**
  (pre-existing packages are never uninstalled) — recorded *before* installing;
- every config file it deployed and the path of the backup it took;
- the PSFzf module location, the font files/registry values and the data dirs
  it added (each with a `preexisting` flag), and whether it built bat's cache;
- the previous Windows Terminal default profile and Windows default-terminal-app
  values, so they can be restored exactly.

It no longer flips **PSGallery** to *Trusted*: PSFzf is saved with
`Save-PSResource -TrustRepository` (trust for that one call only).

## Gotchas (learned during bring-up)

- `install.ps1` / `uninstall.ps1` are **ASCII-only** on purpose: they run under
  Windows PowerShell 5.1, which reads a no-BOM `.ps1` as ANSI and turns
  em-dashes/smart quotes into phantom string delimiters that break parsing.
- **Why it used to take ~5 s to start:** posh-git + PSFzf imported on every
  start (~0.5 s each), `starship init` / `zoxide init` spawning processes, a
  trailing newline in `starship.toml`. Now: no posh-git, PSFzf loaded on first
  use, init scripts cached in `%LOCALAPPDATA%\cli_tweaks\cache` (rebuilt when
  the tool or `starship.toml` changes; delete the folder to force it).
- **starship's `format` must not end with a newline**: bash strips it, pwsh
  prints it, and the cursor ends up on the line below the `▸`.
- **btop's command is `btop4win`** on Windows (no `btop` shim); the profile
  maps `top`/`htop` to it.
- winget installs pwsh 7 as the **MSIX/Store build** (alias in
  `…\WindowsApps\pwsh.exe`), not an MSI under `Program Files`.
- **WezTerm nightly, not stable**: the last stable release is from 2024-02;
  the config was tested against nightly 20261010.
- WezTerm's **integrated title-bar buttons** render as a dot and a dash with a
  Nerd Font, hence the normal Windows title bar (`TITLE|RESIZE`).
- `tldr --update` failing with **os error 10013** = a firewall blocking
  `tldr.exe`, not a tealdeer bug.
