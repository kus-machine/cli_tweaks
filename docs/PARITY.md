# Feature Parity Matrix

The **canonical experience** is defined by the Ubuntu 24 setup (`Ubuntu24/`).
Every other platform aims to reproduce it as closely as the OS allows.

Legend: ✅ done · 🟡 partial / drifted · 📝 planned · 🚫 not applicable

| Capability            | Tool / mechanism                    | Ubuntu24 | macOS (zsh) | Windows (pwsh7) |
|-----------------------|-------------------------------------|:--------:|:-----------:|:---------------:|
| Prompt                | **starship** (`shared/starship.toml`)| ✅       | 🟡 manual PS1| ✅              |
| Terminal emulator     | **alacritty** (`shared/alacritty.toml`)| ✅     | 📝          | ✅              |
| Font                  | FiraCode Nerd Font                   | ✅       | 📝          | ✅              |
| `ls` w/ icons         | **eza** — `l` `la` `lss`             | ✅       | 🟡 partial  | ✅              |
| `tree`                | eza `--tree` + `tr` fn               | ✅       | 🟡 uses `tree`| ✅            |
| find                  | `fin` helper                         | ✅       | 🚫          | ✅              |
| Fuzzy search          | **fzf** + fd (Ctrl+T/R, Alt+C)       | ✅       | 🟡 no fd cfg| ✅ (PSFzf)      |
| Smart cd              | **zoxide** (`z`)                     | 🟡 *not wired* | 🟡 *not wired* | ✅          |
| History (big, dedup, prefix ↑↓) | shell history opts        | ✅       | ✅          | ✅ (PSReadLine) |
| git shortcuts         | `gs` (+ `gd` `gl`)                   | ✅ gs    | ✅ gs/gd/gl/gl1| ✅ gs/gd/gl    |
| System monitor        | **btop** (`top`/`htop`)             | ✅       | 🚫          | ✅ (btop4win)   |
| Multiplexer           | **tmux** (`t`/`ta`/`tk`/`tn`)       | ✅       | ✅          | 🚫 (no tmux)    |
| Word-jump keys        | Alt/Ctrl + arrows                    | ✅       | ✅          | ✅              |

Windows was installed and verified on 2026-07-12 (Windows 11, pwsh 7.6.3): all
tools install via winget, the profile loads clean, and every macro/tool resolves.
Interactive fzf keybindings and the live starship prompt need a real terminal to
eyeball, but their init runs without error.

SSH config and a Raspberry Pi / remote profile are planned separately — see
[PLAN.md](PLAN.md).

## Known drift / cleanup to reconcile

- **zoxide is documented but never wired.** The macOS README tells you to
  `brew install zoxide`, but neither `.zshrc` nor Ubuntu's `.bashrc` runs
  `zoxide init`. Decision: **adopt zoxide as canonical** and add `zoxide init`
  to Ubuntu, macOS, Windows, and (optionally) remote.
- **git aliases differ**: Ubuntu has only `gs`; macOS has `gs/gd/gl/gl1`.
  Canonical set going forward: `gs`, `gd`, `gl` (drop `gl1` or fold into `gl`).
- **tree**: macOS aliases the classic `tree` binary; canonical is eza `--tree`.
- **tmux.conf** is duplicated (`Ubuntu24/` and `macos/`) and 99% identical —
  candidate to move into `shared/tmux.conf`.
