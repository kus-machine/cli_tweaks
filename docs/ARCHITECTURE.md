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
│   ├── alacritty.toml       # terminal — used by Linux/macOS/Windows
│   └── starship.toml        # prompt   — used by every shell
├── Ubuntu24/                # Linux — the CANONICAL experience
│   ├── install.sh           # flag dispatcher (--packages --fonts ... --all)
│   ├── scripts/*.sh         # one installer per component + common.sh
│   └── configs/             # .bashrc, .bash_aliases, .blerc, .tmux.conf
├── macos/                   # macOS (zsh) — being brought up to parity
│   ├── .zshrc, .tmux.conf
│   └── install.sh           # 📝 planned
└── windows/                 # Windows 11 — native PowerShell 7
    ├── install.ps1          # winget-based, per-user, flag/switch model
    └── Microsoft.PowerShell_profile.ps1
```

Planned-but-not-yet-built pieces (SSH config, Raspberry Pi / remote profile)
are tracked in [PLAN.md](PLAN.md), not present in the tree yet.

## Design principles

1. **One canonical experience.** Ubuntu24 defines the target UX; `docs/PARITY.md`
   tracks how faithfully each platform reproduces it. Change the canon there
   first, then propagate.

2. **`shared/` is the single source of truth for portable configs.** Anything
   whose format is identical across OSes (starship, alacritty) lives in
   `shared/` and is *referenced* by each platform's installer — never copied
   into a platform folder. Per-shell files (`.bashrc`, `.zshrc`, the PS profile)
   stay platform-local because their syntax differs.

3. **Installers are componentised and idempotent-ish.** Each platform exposes
   the same component switches (`packages`, `fonts`, `starship`, `configs`,
   `alacritty`; Windows adds `shell` for pwsh7, Ubuntu adds `blesh` for the
   inline autosuggestions bash lacks natively). Existing user files are backed
   up (`*.bak.<timestamp>`) before being overwritten.

4. **Everything degrades gracefully.** Shell profiles guard each tool behind a
   presence check (`command -v` / `Get-Command`) so a partial install never
   produces a broken shell.

5. **Per-user, no admin where possible.** Windows uses winget + per-user font
   registration; nothing requires elevation for the core experience.

## Platform notes

- **Windows = native PowerShell 7 only** (decision: no WSL, no tmux/bash). The
  machine currently has only Windows PowerShell 5.1, so `install.ps1 -Shell`
  installs pwsh7 first; the profile lands at `~/Documents/PowerShell/`.
- **Terminal = Alacritty everywhere** for one shared TOML.
