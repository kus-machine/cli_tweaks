# cli_tweaks

My personal CLI setup — one consistent, Ubuntu-24-style terminal experience
across **Linux, macOS, and Windows 11**.

Fuzzy search (fzf), icon `ls` (eza), a nice prompt (starship), the Alacritty
terminal, and handy macros — installed the same way, feeling the same way,
everywhere.

## What you get

- **Prompt:** starship (`shared/starship.toml`)
- **Terminal:** Alacritty, Tokyo Night, FiraCode Nerd Font (`shared/alacritty.toml`)
- **Fuzzy search:** fzf + fd — `Ctrl+T` files, `Ctrl+R` history, `Alt+C` cd
- **Inline autosuggestions:** grey completion-as-you-type from history —
  ble.sh (bash), zsh-autosuggestions (zsh), PSReadLine prediction (pwsh)
- **Macros:** `l`/`la`/`lss` (eza), `tr` (tree), `fin` (find), `gs` (git status),
  `top`/`htop` → btop, tmux helpers `t`/`ta`/`tk`/`tn` (Linux/macOS)

See **[docs/PARITY.md](docs/PARITY.md)** for exactly what's wired on each platform.
Planned work (macOS parity, SSH config, Raspberry Pi) lives in
**[docs/PLAN.md](docs/PLAN.md)**.

## Quickstart

| Platform | How to install |
|----------|----------------|
| **Linux (Ubuntu 24)** | `cd Ubuntu24 && chmod +x install.sh scripts/*.sh && ./install.sh --all` |
| **Windows 11** | `cd windows; ./install.ps1 -All`  *(installs PowerShell 7 + tools; draft)* |
| **macOS** | 📝 planned — see [docs/PLAN.md](docs/PLAN.md) |

Each installer is componentised — install only what you want. Linux example:

```bash
./install.sh --packages --starship --configs   # skip fonts/alacritty
```

Windows example:

```powershell
./install.ps1 -Shell -Packages -Starship -Configs   # pwsh7 + tools + prompt + profile
```

Existing dotfiles are backed up (`*.bak.<timestamp>`) before anything is written.

## Repo layout

See **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)**. TL;DR: `shared/` holds
portable configs, each platform folder holds its shell-specific bits + installer,
`docs/` holds the plan and parity matrix.

## Status

Active project. Current state and roadmap live in **[docs/PLAN.md](docs/PLAN.md)**.
