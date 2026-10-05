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
| `tree`                | eza `tree [depth]` + `tree1`..`tree9` | ✅       | 🟡 blind, untested | 🟡 untested |
| find                  | `fin` — fd from the current dir      | ✅       | 📝          | ✅              |
| Fuzzy search          | **fzf** + fd (Ctrl+T/R, Alt+C)       | ✅       | 🟡 no fd cfg| ✅ (PSFzf; Alt+C 🟡 untested) |
| Command examples      | **tldr** (tealdeer) + `F1` while typing | ✅ | 📝 | 📝 |
| fzf previews          | bat file / eza tree / full command, `Ctrl+/` toggles | ✅ | 📝 | 📝 |
| Inline autosuggestion | grey text as you type                | ✅ ble.sh| ✅ zsh-autosuggestions | ✅ PSReadLine |
| Input-line colours    | Tokyo Night faces (`Ubuntu24/configs/.blerc`) | ✅ | 📝          | 📝              |
| Smart cd              | **zoxide** (`z`, `zi`)               | ✅       | 🟡 *not wired* | ✅          |
| History (big, dedup, prefix ↑↓) | shell history opts        | ✅       | 🟡 blind, untested | ✅ (PSReadLine) |
| git shortcuts         | `gs` `gd` `gl`                       | ✅       | ✅ gs/gd/gl/gl1| 🟡 gs/gd/gl (`gl` fix untested) |
| System monitor        | **btop** (`top`/`htop`)             | ✅       | 📝          | ✅ (btop4win)   |
| Multiplexer           | **tmux** (`t`/`ta`/`tk`/`tn`)       | ✅       | ✅          | 🚫 (no tmux)    |
| Copy to clipboard     | tmux copy-pipe + `Alt+W` on the line | ✅ xclip | 🟡 pbcopy, untested | 🟡 terminal only |
| Word-jump keys        | Alt/Ctrl + arrows                    | ✅       | 🟡 blind, untested | ✅       |
| Word-delete keys      | Ctrl/Alt+Backspace ⌫word, Ctrl+Del word⌦ | ✅ ble.sh + readline fallback | 🟡 blind, untested | ✅ PSReadLine, pinned |
| Uninstall / revert    | manifest-driven uninstaller          | ✅       | 📝          | ✅              |
| Startup banner + `keys` | cat + key macros on a new terminal; `keys` = full cheatsheet | ✅ | 📝 | 📝 |

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
`Ctrl+T`/`Ctrl+R`/`Alt+C` and `UP` prefix search all still work. (The original
note here said startup was "unchanged, 0.27 s with and without" — that was
wrong. Measured 2026-10-05 on the laptop, time to first prompt: 0.14 s without
ble.sh, ~0.6 s with it — about 0.25 s to load ble.sh plus 0.17 s for
`ble-attach`, both inherent — and ~1.7 s once after every (re)install while
its caches rebuild; see the ble.sh startup notes in CLAUDE.md.) ble.sh's syntax highlighting is
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

Review pass on 2026-10-05 (code read + checks on the Ubuntu laptop) fixed
several things that looked fine but were not:

- **`tr` is gone**, folded into `tree [depth] [path]` plus `tree1`..`tree9`
  shorthands (`tree3 /etc`), on all three shells. A bash function named `tr` shadowed
  coreutils `tr`: `echo foo | tr a-z A-Z` printed the helper's usage, and the
  bash-completion scripts for gcc, java, update-rc.d, invoke-rc.d,
  add-apt-repository and xdg-settings call `tr` internally, so their `Tab`
  silently broke.
- **Windows `gl` printed the current directory**: `gl` is PowerShell's built-in
  alias for `Get-Location`, and aliases beat functions. The profile now
  removes it first (not yet re-checked on Windows).
- **macOS UP/DOWN** used zsh's `history-search-backward`, which matches only the
  *first word* of the line; now `up/down-line-or-beginning-search` (whole
  prefix, cursor to end) — still untested on a Mac.
- **`fin`** on Ubuntu was `sudo find /` (password, crawls /proc and every
  mount); it now matches Windows: fd from the current directory. Both shells
  use the same fzf `--exclude` list.
- `l`/`la`/`lss` lost eza's `-h`, which is `--header`, not "human-readable".
- `tk` outside tmux now lists the sessions and asks before `kill-server`.
- Installers/uninstallers: re-runs no longer relabel what we installed as
  `preexisting` (Ubuntu), pre-existing fonts and pwsh modules are kept on
  uninstall, `uninstall.ps1 -Cosmetic` is safe to repeat, and `install.ps1`
  writes its manifest even when a component fails.

## Known drift / cleanup to reconcile

- **zoxide is wired on Ubuntu and Windows only.** The macOS README tells you to
  `brew install zoxide`, but `.zshrc` does not run `zoxide init` yet.
  Decision: **adopt zoxide as canonical** and add `zoxide init`
  to Ubuntu, macOS, Windows, and (optionally) remote.
- **git aliases**: `gs/gd/gl` everywhere now; macOS still has an extra `gl1`
  (drop it or fold it into `gl`).
- **`fin`, btop on macOS** are simply not wired yet (part of PLAN step 3), not
  "not applicable".
- **tmux.conf** is duplicated (`Ubuntu24/` and `macos/`) and 99% identical —
  candidate to move into `shared/tmux.conf`.
