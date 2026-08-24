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
| Inline autosuggestion | grey text as you type                | ✅ ble.sh| ✅ zsh-autosuggestions | ✅ PSReadLine |
| Input-line colours    | Tokyo Night faces (`Ubuntu24/configs/.blerc`) | ✅ | 📝          | 📝              |
| Smart cd              | **zoxide** (`z`)                     | 🟡 *not wired* | 🟡 *not wired* | ✅          |
| History (big, dedup, prefix ↑↓) | shell history opts        | ✅       | ✅          | ✅ (PSReadLine) |
| git shortcuts         | `gs` (+ `gd` `gl`)                   | ✅ gs    | ✅ gs/gd/gl/gl1| ✅ gs/gd/gl    |
| System monitor        | **btop** (`top`/`htop`)             | ✅       | 🚫          | ✅ (btop4win)   |
| Multiplexer           | **tmux** (`t`/`ta`/`tk`/`tn`)       | ✅       | ✅          | 🚫 (no tmux)    |
| Copy to clipboard     | tmux copy-pipe + `Alt+W` on the line | ✅ xclip | 🟡 pbcopy, untested | 🟡 terminal only |
| Word-jump keys        | Alt/Ctrl + arrows                    | ✅       | 🟡 blind, untested | ✅       |
| Word-delete keys      | Ctrl/Alt+Backspace ⌫word, Ctrl+Del word⌦ | ✅ ble.sh + readline fallback | 🟡 blind, untested | ✅ PSReadLine, pinned |
| Uninstall / revert    | manifest-driven uninstaller          | ✅       | 📝          | ✅              |

Windows was installed and verified on 2026-07-12 (Windows 11, pwsh 7.6.3): all
tools install via winget, the profile loads clean, and every macro/tool resolves.
Interactive fzf keybindings and the live starship prompt need a real terminal to
eyeball, but their init runs without error.

SSH config and a Raspberry Pi / remote profile are planned separately — see
[PLAN.md](PLAN.md).

Inline autosuggestions landed on Ubuntu on 2026-07-28 via **ble.sh**
(`./install.sh --blesh`), which is the only way to get them in bash — readline
cannot draw ahead of the cursor. Verified live: suggestion in grey 242 (same
shade as the Windows profile's `InlinePrediction`), `Tab` completion, fzf
`Ctrl+T`/`Ctrl+R`/`Alt+C` and `UP` prefix search all still work, and shell
startup is unchanged (0.27 s with and without). ble.sh's syntax highlighting is
kept but re-themed to Tokyo Night in `Ubuntu24/configs/.blerc`; its stock
palette was rejected. macOS gets the same suggestion feel from
`zsh-autosuggestions`, which `macos/.zshrc` already sources; its suggestion
colour is not pinned to 242 yet, and neither zsh nor pwsh colours the input
line at all yet (`zsh-syntax-highlighting` is installed on macOS but unthemed).

Ubuntu was re-verified on 2026-07-28 (Ubuntu 24.04, kernel 6.17 OEM) after two
real bugs were fixed: `.bashrc` sourced fzf's completion before bash-completion
(killing `Tab` in every non-login shell — i.e. everywhere except tmux), and the
installer had no uninstaller and destroyed the user's original dotfiles by
re-backing-up its own output on each run.

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
