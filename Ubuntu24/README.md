# Ubuntu 24 CLI Tweaks

Personal Ubuntu terminal setup including:

- Bash improvements
- Tmux configuration
- Starship prompt
- Alacritty configuration
- Nerd Fonts
- Common CLI utilities

## Clone Repository

```bash
git clone https://github.com/kus-machine/cli_tweaks.git
cd cli_tweaks

chmod +x install.sh uninstall.sh
chmod +x scripts/*.sh
```

## Available Components

### --packages

Installs useful command-line tools:

- bash-completion (required — see [Tab completion](#tab-completion))
- git
- xclip (clipboard — see [Copying text out of the terminal](#copying-text-out-of-the-terminal))
- jq (used to track what the installer changes)
- tmux
- eza
- tree
- fzf
- fd
- ripgrep
- btop

```bash
./install.sh --packages
```

---

### --fonts

Installs FiraCode Nerd Font required for icons and enhanced terminal rendering.

```bash
./install.sh --fonts
```

---

### --configs

Installs:

- .bashrc
- .bash_aliases
- .tmux.conf
- .blerc (ble.sh settings + palette — inert if ble.sh is not installed)

Your original files are captured **once**, on the first install, into
`~/.local/state/cli_tweaks/pristine/` (plus one timestamped `.bak` beside the
file). Re-running the installer does not pile up further backups.

```bash
./install.sh --configs
```

---

### --starship

Installs:

- Starship prompt
- starship.toml configuration

Provides:

- Git status
- Runtime versions
- Compact modern prompt

```bash
./install.sh --starship
```

---

### --blesh

Installs [ble.sh](https://github.com/akinomyoga/ble.sh) (Bash Line Editor) into
`~/.local/share/blesh`.

Provides:

- **Inline autosuggestions** — grey completion of the command you are typing,
  drawn from your history, exactly like zsh-autosuggestions on macOS and
  PSReadLine's InlinePrediction on Windows. `Right`/`End`/`Ctrl+F` accept it,
  `Ctrl+Right`/`Alt+F` accept one word, `Ctrl+G` dismisses it.
- **Syntax highlighting of the line you type**, re-themed to Tokyo Night so it
  matches the terminal (`shared/alacritty.toml`) instead of ble.sh's default
  palette — which paints builtins red, globs hot pink and puts white-on-red
  blocks behind errors. The whole palette lives in `configs/.blerc`
  (deployed to `~/.blerc`, which ble.sh sources by itself):

  | | |
  |---|---|
  | external command (`git`) | blue `#7aa2f7` |
  | builtin (`cd`, `echo`) | cyan `#7dcfff` |
  | your alias / function (`l`, `tr`) | teal `#73daca` |
  | keyword (`if`, `for`) | magenta `#bb9af7` |
  | `"string"` / heredoc | green `#9ece6a` |
  | `$var`, `${...}`, globs, braces | yellow `#e0af68` |
  | `\|`, `;`, `&&` | light blue `#89ddff` |
  | comment, unset var, hints | grey `#565f89` |
  | syntax error, dangling symlink | red `#f7768e` |

  No underlines, no bold, no background blocks — hue only. Turn a whole layer
  off with `bleopt highlight_syntax=` / `highlight_filename=` /
  `highlight_variable=` in `~/.blerc`.

```bash
./install.sh --blesh
```

There is no `blesh` apt package on Ubuntu 24.04, so the installer downloads
upstream's prebuilt nightly tarball (no build tools needed). `--configs` is what
actually wires it into `.bashrc`; installing one without the other is harmless —
the `.bashrc` block is guarded and simply does nothing if ble.sh is missing.

---

### --alacritty

Installs:

- Alacritty terminal
- Alacritty configuration

Provides:

- GPU accelerated terminal
- Transparency
- Modern rendering

```bash
./install.sh --alacritty
```

---

## Install Everything

```bash
./install.sh --all
```

This installs:

- CLI packages
- Nerd Fonts
- Bash configuration
- Tmux configuration
- Starship
- ble.sh (inline autosuggestions)
- Alacritty

---

## Combine Features

Examples:

```bash
./install.sh --packages --starship

./install.sh --fonts --starship --configs

./install.sh --alacritty --configs
```

---

## Uninstall / return to default

Every install records what it did in
`~/.local/state/cli_tweaks/install-manifest.json`, so the uninstaller can revert
it **without ever removing something that was already on the machine**.

```bash
./uninstall.sh --configs            # restore original dotfiles, keep the tools
./uninstall.sh --full               # also remove packages/fonts/starship WE added
./uninstall.sh --full --dry-run     # show what would happen, change nothing
```

`--configs` is the "make my shell normal again" button. `--full` additionally
apt-removes only the packages whose manifest entry says `preexisting: false`,
and deletes `~/.local/share/blesh` + `~/.cache/blesh` if we were the ones who
put ble.sh there.

The pristine copies are deliberately kept after `--full`, so a later re-install
still has your real originals to fall back on. Delete
`~/.local/state/cli_tweaks/` by hand if you want them gone.

---

## Activate Bash Changes

```bash
source ~/.bashrc
```

---

## Tab completion

`bash-completion` **must be sourced before fzf's completion script**, and
`configs/.bashrc` does exactly that. If you reorder those two blocks, plain
`Tab` (e.g. `git stat<Tab>`) silently stops working in Alacritty and GNOME
Terminal while continuing to work inside tmux — because tmux starts a *login*
shell, where `/etc/profile.d/bash_completion.sh` has already loaded
bash-completion before `~/.bashrc` runs. The long comment above that block in
`configs/.bashrc` explains the mechanism.

---

## Keys on the command line (with ble.sh)

| Key | What it does |
|-----|--------------|
| `Right` / `End` / `Ctrl+F` | accept the whole grey suggestion |
| `Ctrl+Right` / `Alt+F` | accept one word of it |
| `Esc` (or `Ctrl+G`) | dismiss the suggestion |
| `UP` / `DOWN` | prefix history search — type `cd `, press UP, walk older matches. Instant, readline-style: no status line, and the recalled line is *not* left selected, so you can keep typing on it |
| `Tab` | complete; a second `Tab` opens the candidate menu |
| *(in the menu)* type anything | drops the highlighted candidate, inserts your character and narrows the list — keep typing, then `Tab` again for fewer candidates |
| *(in the menu)* `Tab` / `Shift+Tab` / arrows | move through candidates |
| *(in the menu)* `Enter` | take the highlighted candidate |
| *(in the menu)* `Esc` / `Ctrl+C` / `Ctrl+G` | leave the menu, line back the way you typed it |
| `Ctrl+T` / `Ctrl+R` / `Alt+C` | fzf: files / history / cd |

**`Esc` is the universal way out**: it drops the grey suggestion, leaves the Tab
menu, and abandons a history or incremental search — everywhere ble.sh offers
only `Ctrl+G`. `Ctrl+G` keeps working; `Esc` is just the second, obvious key. At
a plain prompt it does nothing, quietly.

If `Esc` instead prints something like `unbound keyseq: C-M-[ C-M-[`, that shell
was started before this config landed — `~/.blerc` is only read when the shell
starts. Open a new terminal and check with:

```bash
bleopt decode_isolated_esc     # must print: bleopt decode_isolated_esc=esc
```

None of that is stock ble.sh — `configs/.blerc` rebinds it. Out of the box
`Ctrl+G` is the only escape hatch (everything else beeps "unbound keyseq"),
typing in the menu keeps the highlighted candidate so a long list can only be
narrowed by deleting it by hand first, and UP/DOWN open an interactive search
session that parks a `(nsearch#1: << !504 >>)` status line and leaves the result
selected — where the next character you type replaces it.

---

## Copying text out of the terminal

Three different selections exist and they are easy to confuse. Which one you get
depends on whether tmux is running and whether Shift is held:

| Where you are | How to select | How to copy |
|---|---|---|
| **No tmux** | drag with the mouse | automatic — `selection.save_to_clipboard` is on (`Ctrl+Shift+C` still works) |
| **In tmux** | drag with the mouse (the orange selection) | automatic on release, piped through `xclip` |
| **In tmux** | double-click a word / triple-click a line | automatic, same pipe |
| **In tmux**, scrolled back | wheel or `Shift+PageUp` enters copy-mode, then drag — or `Space` to start a keyboard selection | mouse release, or `Enter` |
| **On the command line** | `Shift`+arrows | `Alt+W` (with nothing selected it copies the whole line) |

Paste is unchanged: `Ctrl+Shift+V`, or middle-click for the primary selection.

Why the old way fought you: **under tmux, `Shift`+drag + `Ctrl+Shift+C` can never
scroll**. That selection belongs to Alacritty, and while tmux is running
Alacritty's scrollback is empty — the history lives inside tmux. Anything that
scrolls has to be tmux's copy-mode, and then the copy has to be tmux's too.

And why tmux copies only *sometimes* reached the clipboard: tmux's default
`set-clipboard external` hands the text to the terminal as an OSC 52 escape
sequence, which Alacritty accepts only under some `TERM` values. `.tmux.conf`
now pipes every copy through `xclip` instead, which does not depend on the
terminal at all. That makes **xclip a real dependency** (it is in
`--packages`); without it, tmux copies fall back to the flaky path and `Alt+W`
has nowhere to put the text.

`Alt+W` exists because ble.sh's own copy only fills its internal kill-ring —
which is why a `Shift`+arrow selection could be deleted but never pasted
anywhere else. It fills both now, so `Ctrl+Y` still yanks it back.

---

## No grey suggestions while typing?

They come from ble.sh, not from Alacritty — a terminal cannot do this, only the
line editor can. Check, in order:

```bash
ls ~/.local/share/blesh/ble.sh   # installed?      -> ./install.sh --blesh
echo "$BLE_VERSION"              # loaded?         -> ./install.sh --configs
```

`.bashrc` loads ble.sh in **two halves**: `source .../ble.sh --attach=none` at
the very top (so bash-completion, fzf, starship and the `bind` lines below all
register through ble.sh) and `ble-attach` as the very last line of the file.
Merging them, or adding key/prompt setup after `ble-attach`, breaks the setup.

Under ble.sh the fzf keybindings come from ble.sh's own
`integration/fzf-{completion,key-bindings}` modules instead of
`/usr/share/doc/fzf/examples/key-bindings.bash` — the stock script binds through
readline, which ble.sh has replaced, and its `Ctrl+R` would fight ble.sh over
the history widget. `.bashrc` keeps the stock path only as the no-ble.sh
fallback.

---

## Alacritty will not start?

Alacritty is a GPU terminal and needs a working OpenGL/GLX context. If it exits
immediately with something like

```
Error: Error { raw_code: Some(2), raw_os_message: Some("BadValue (integer
parameter out of range for operation)"), kind: BadAttribute }
```

that is a **graphics-driver problem, not a config problem**. Confirm with:

```bash
glxinfo -B     # fails the same way -> the whole GL stack is broken
nvidia-smi     # "Driver/library version mismatch" -> reboot after a driver upgrade
```

A driver upgrade replaces the userspace libraries immediately but the kernel
module in RAM stays at the old version until you reboot.