# Architecture

## Layout

```
cli_tweaks/
├── README.md                # entry point + per-platform quickstart
├── CLAUDE.md                # guide for AI assistants working in this repo
├── docs/
│   ├── PLAN.md              # roadmap, status, decisions, next steps
│   ├── PARITY.md            # canonical feature matrix across platforms
│   └── ARCHITECTURE.md      # this file
├── shared/                  # portable, platform-agnostic configs (single source)
│   ├── wezterm.lua          # terminal with tabs + panes — Windows and Ubuntu
│   ├── starship.toml        # prompt   — used by every shell
│   ├── lesskey              # less's keys on the Ukrainian layout (Windows + Ubuntu)
│   └── bat/themes/          # bat colour themes (tokyonight_night = default)
├── Ubuntu24/                # Linux — the CANONICAL experience
│   ├── install.sh           # flag dispatcher (--packages --fonts ... --all)
│   ├── uninstall.sh         # manifest-driven revert (--configs / --full)
│   ├── scripts/*.sh         # one installer per component + common.sh
│   └── configs/             # .bashrc, .bash_aliases, .blerc, .tmux.conf
├── macos/                   # macOS (zsh) — being brought up to parity
│   ├── .zshrc, .tmux.conf
│   └── install.sh           # 📝 planned
├── legacy/alacritty/        # parked, NOT maintained: Ubuntu's Alacritty option (until 2026-10-18)
├── tests/                   # ubuntu-configs-roundtrip.sh (install/uninstall in a temp $HOME)
├── .github/workflows/       # check.yml: CI on every push (shellcheck, .ps1 parse, round trip)
└── windows/                 # Windows 11 — native PowerShell 7 + WezTerm
    ├── install.ps1          # winget-based, per-user, flag/switch model
    ├── uninstall.ps1        # manifest-driven revert (-Cosmetic / -Full)
    ├── keys.txt             # the `keys` / Ctrl+B ? cheatsheet (Ubuntu: in .bash_aliases)
    └── Microsoft.PowerShell_profile.ps1
```

Planned-but-not-yet-built pieces (SSH config, Raspberry Pi / remote profile)
are tracked in [PLAN.md](PLAN.md), not present in the tree yet.

## Design principles

1. **One canonical experience.** Ubuntu24 defines the target UX; `docs/PARITY.md`
   tracks how faithfully each platform reproduces it. Change the canon there
   first, then propagate.

2. **`shared/` is the single source of truth for portable configs.** Anything
   whose format is identical across OSes (starship, wezterm) lives in
   `shared/` and is *referenced* by each platform's installer — never copied
   into a platform folder. Per-shell files (`.bashrc`, `.zshrc`, the PS profile)
   stay platform-local because their syntax differs.

3. **Installers are componentised and idempotent-ish.** Each platform exposes
   the same component switches (`packages`, `fonts`, `starship`, `configs`,
   plus the terminal `wezterm`; Windows adds
   `shell` for pwsh7, Ubuntu adds `blesh` for the inline autosuggestions bash
   lacks natively). A user file is captured **once**
   before it is first overwritten (Ubuntu: `~/.local/state/cli_tweaks/pristine/`;
   Windows: `*.bak.<timestamp>`), and everything an install does goes into a
   manifest that the uninstaller replays in reverse. Anything that was already
   there is flagged `preexisting` and never removed.

4. **Everything degrades gracefully.** Shell profiles guard each tool behind a
   presence check (`command -v` / `Get-Command`) so a partial install never
   produces a broken shell.

5. **Per-user, no admin where possible.** Windows uses winget + per-user font
   registration; nothing requires elevation for the core experience.

## Platform notes

- **Windows = native PowerShell 7 only** (decision: no WSL, no tmux/bash).
  `install.ps1 -Shell` installs pwsh7 if missing; the profile lands at
  `~/Documents/PowerShell/profile.ps1`, its data files (`keys.txt`, `lesskey`)
  in `~/.config/cli_tweaks/`.
- **Terminal: WezTerm on Windows and Ubuntu** (Windows since 2026-10-12;
  Ubuntu's Alacritty option parked in `legacy/` on 2026-10-18, see PLAN.md
  decision 2). WezTerm brings tabs/panes with the tmux keys; tmux stays on
  Ubuntu for SSH and detached sessions. macOS: decided in the Mac pass.
