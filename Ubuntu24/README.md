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
cd cli_tweaks/Ubuntu24
```

The scripts are committed as executable, so no `chmod` is needed.

## Available Components

### --packages

Installs useful command-line tools:

- bash-completion (required — see [Tab completion](#tab-completion))
- curl
- git
- xclip (clipboard — see [Copying text out of the terminal](#copying-text-out-of-the-terminal))
- jq (used to track what the installer changes)
- tmux
- eza
- tree
- bat (`cat` with syntax colours; also draws the fzf file preview — theme
  `tokyonight_night`; switch with `export BAT_THEME=...` in `~/.bashrc.local`)
- fzf
- fd
- ripgrep
- zoxide (`z` / `zi` — jump to frequent folders)
- tealdeer (`tldr` — short ready-made examples; pages downloaded once, ~30 MB)
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
- bat colour themes (`shared/bat/themes` → `~/.config/bat/themes`, then
  `bat cache --build`): **tokyonight_night**, the default, and synthwave84

Your original files are captured **once**, on the first install, into
`~/.local/state/cli_tweaks/pristine/` (plus one timestamped `.bak` beside the
file). Re-running the installer does not pile up further backups.

If an older, pre-manifest version of this installer already ran on the machine,
the file in your home is *its* deploy, not your original. The installer notices
the `.bak` / `.bak.<timestamp>` files that version left beside it and captures
the **oldest** of them as your original instead (it says so in yellow).

Machine-local lines — your own, or what nvm/conda/cargo/sdkman want to append —
go in **`~/.bashrc.local`**, not in `~/.bashrc`: `--configs` replaces
`~/.bashrc` on every run, while `~/.bashrc.local` is never touched and is
sourced at the end of `.bashrc` (just before ble.sh attaches).

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
  | your alias / function (`l`, `tree`) | teal `#73daca` |
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

Re-running `--blesh` (or `--all`) does **not** reinstall a ble.sh it already
put there. To update ble.sh, run `ble-update` in a shell.

ble.sh makes a new terminal take ~0.6 s to show the prompt instead of ~0.15 s
(0.25 s to load it, 0.17 s to attach — its own cost). Two one-off things can
make it slower or noisier:

- **The first terminal after installing or updating ble.sh** rebuilds its
  caches in `~/.cache/blesh` for that `$TERM` (~1.7 s) and prints
  `ble/term.sh: updating tput cache for TERM=...`. Alacritty and tmux use
  different `TERM`s, so each does it once.
- **Power-saver mode** (`powerprofilesctl get`) slows ble.sh, which is plain
  bash code, by roughly 2×.

`.blerc` already removes the two avoidable costs: it applies the whole colour
palette in one `ble-face` call (~110 ms saved) and fixes the character-width
settings, so ble.sh no longer flashes test characters (`[▽] [▶] …`) at
startup to measure the terminal.

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

## Macros

| Command | Does |
|---|---|
| `l` / `la` / `lss` | eza long listing with icons; `la` adds directory sizes, `lss` sorts by size |
| `tree [depth] [path]` | eza tree; `tree 3 /etc` = 3 levels of /etc; other args go to eza (`tree -a`). `command tree` is the classic binary |
| `tree1` … `tree9` | shorthand for the depth: `tree3 /etc` = `tree 3 /etc` |
| `fin <pattern>` | find files from the **current directory**, hidden and git-ignored included (fd; falls back to `find`) |
| `gs` / `gd` / `gl` | `git status` / `git diff` / `git log --graph` |
| `z <part of a path>` / `zi` | zoxide: jump to the best-matching folder you have visited / pick one with fzf |
| `top` / `htop` | btop |
| `CMD; alert` | desktop notification when CMD finishes: "done" or "failed (exit N)" plus the command (needs a desktop session). Try `sleep 5; alert` and switch to another window. Ubuntu's stock alias used `--urgency=low`, which GNOME files under the clock without a pop-up, so it is a function with normal urgency here |
| `t`, `tls`, `ta`, `tn` | tmux, list, attach to the first session, new session |
| `tk` | inside tmux: kill this session; outside: list all sessions and ask before killing the server |
| `tldr CMD` | a few ready-made examples instead of the man page (`tldr tar`, `tldr git-commit`) |
| `keys` | the full cheatsheet: every command above plus all hotkeys (command line, tmux, terminal) |

### Startup banner

A new terminal greets you with an ASCII cat and the commands above that are
easiest to forget, with `keys` for the rest:

```
  ,-.       _,---._ __  / \    cli_tweaks · github.com/kus-machine/cli_tweaks
 /  )    .-'       `./ /   \
(  (   ,'            `/    /|  l  la  lss           list · +sizes · by size
 \  `-"             \'\   / |  tree3 DIR            tree, 3 levels (tree1…9)
  `.              ,  \ \ /  |  fin TEXT             find by name, from here
   /`.          ,'-`----Y   |  z PART               jump to a visited folder
  (            ;        |   '  gs  gd  gl           git status · diff · log
  |  ,-.    ,-'  Andrii |  /   t  ta  tn  tk        tmux · attach · new · kill
  |  | (   |    Pavliuk | /    Ctrl+T Ctrl+R Alt+C  fzf: file · history · cd
  )  |  \  `.___________|/     ↑  →  Alt+W          history · accept · copy
  `--'   `--'                  F1  ·  tldr CMD      examples for a command
                               keys                 all commands & hotkeys
```

- Colours tell the parts apart: commands blue, ARGUMENTS you fill in pale
  grey (always in capitals), keys to press magenta, the title orange. The
  last row, `keys`, is yellow: it is where the full instructions continue.
- It needs 79 columns. From 40 to 78 columns you get one line
  (`=^.^= cli_tweaks · type keys for every hotkey`); below 40, nothing.
- It shows once per terminal: in tmux only in the first pane of a new session
  (not on splits or new windows), and never in a nested `bash`.
- Switch it off with `CLI_TWEAKS_BANNER=0` in `~/.bashrc.local`.
- The cat is by hjw (Hayley Jane Wakenshaw); the credit sits in a comment in
  `configs/.bash_aliases`, where both the banner and `keys` are defined.

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
| `Tab` | complete; the candidates show up right away (a second `Tab` steps into them) |
| `-` or `--`, then `Tab` | the command's options, each with what it does (taken from its man page) |
| `F1` | tldr examples for the command you are typing, printed above the line (which stays); `git commit` + `F1` → the `git-commit` page, `sudo apt install` + `F1` → `apt` (sudo, env, time, `VAR=x` … are skipped); no tldr page → `man` |
| *(in the menu)* type anything | drops the highlighted candidate, inserts your character and narrows the list — keep typing, then `Tab` again for fewer candidates |
| *(in the menu)* `Tab` / `Shift+Tab` / arrows | move through candidates |
| *(in the menu)* `Enter` | take the highlighted candidate |
| *(in the menu)* `Esc` / `Ctrl+C` / `Ctrl+G` | leave the menu, line back the way you typed it |
| `Ctrl+T` / `Ctrl+R` / `Alt+C` | fzf: files / history / cd — each with a preview on the side (file with syntax colours via bat, folder tree via eza, the full command); `Ctrl+/` hides / shows it |

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

## tmux tabs

tmux windows are tabs, each with its own panes. `.tmux.conf` shows them in a
two-line bar at the **top**: the tabs (the active one in blue; named after
the folder, or the program running in it) with session and time on the right
(plus user@host and date in windows of 110+ columns), and under them a hint
line that follows what you are doing:

- normally — the tab keys below;
- right after `Ctrl+B` — a yellow `Ctrl+B …` badge, and the keys that may
  follow (`z` zoom, `Ctrl+arrows` resize, `d` detach, `?` all commands);
- in copy / scroll mode — a `COPY` badge and its keys; in `Ctrl+B w` — the
  keys of the tab list.

tmux's own prompts and messages (rename, "close tab?", "Config reloaded")
also appear on that second line, so they never cover the tabs or the clock.

| Key | Does |
|---|---|
| `Alt+1` … `Alt+9`, or a click | go to tab N |
| `Alt+T` | new tab, in the current folder |
| `Alt+N` / `Alt+K` | rename the tab / close tab (asks first; Enter = yes) |
| `Ctrl+B w` | all tabs with previews |

New tabs and new panes (`Ctrl+B |`, `-`) open in the folder of the pane you
are in, not the folder the session was started from. None of the tab keys
need `Ctrl+B`. Inside tmux, `Alt+1..9` and `Alt+T` belong to tmux (in the
shell they were readline's digit-argument and transpose-words); `Alt+N` and
`Alt+K` were free. `Ctrl+K` was not used on purpose: it is the shell's
delete-to-end-of-line.

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
A paste that ends in a newline (a triple-clicked line, most copies from a
browser) has that **one trailing newline dropped** by `~/.blerc`, so a single
line lands as a normal editable line instead of switching ble.sh to
`-- MULTILINE --`. Real multi-line pastes still get MULTILINE.

**With the Ukrainian layout on**, `Ctrl+Shift+C/V`, `Ctrl+C`, `Ctrl+R`,
`Alt+C` and every other `Ctrl+letter` / `Alt+letter` work exactly as on the
Latin layout. Alacritty matches bindings against the character the active
layout produces (`Ctrl+Shift+М`, not `V`); `shared/alacritty.toml` maps every
Ukrainian letter back to the Latin key on the same key cap, the way GNOME
Terminal does on its own. tmux gets the same treatment: every prefix key
in use is bound a second time under its Ukrainian letter (`Ctrl+B в` =
detach, `Ctrl+B с` = new window, `Ctrl+B ґ` = split right, since `|` needs
AltGr there). Only `x` / `&` (kill pane / window, whose confirmation takes a
Latin `y`) and `$` (rename session) still need the Latin layout.

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