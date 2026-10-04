# CLAUDE.md

Guide for AI assistants (and future-me) working in this repo.

## What this repo is

Personal, single-user dotfiles/CLI setup. The **goal** is one consistent
Ubuntu-24-style terminal experience across Linux, macOS, and Windows 11 (native
PowerShell 7). A lightweight remote SSH profile (Raspberry Pi) is a planned
future target — see [docs/PLAN.md](docs/PLAN.md).

Read these first: [docs/PLAN.md](docs/PLAN.md) (roadmap + status + decisions),
[docs/PARITY.md](docs/PARITY.md) (canonical feature matrix),
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) (layout + principles).

## Golden rules

1. **Ubuntu24 is the canonical experience.** When adding a feature, define it in
   the Ubuntu configs + PARITY.md first, then propagate to other platforms.
2. **Portable configs live in `shared/`** (starship, alacritty). Platform
   installers *reference* them; never copy a shared file into a platform folder.
   If you change where a shared file lives, update every installer that reads it
   (currently: `Ubuntu24/scripts/install-{starship,alacritty}.sh`,
   `windows/install.ps1`).
3. **Per-shell files stay platform-local** because syntax differs:
   `Ubuntu24/configs/.bashrc` + `.bash_aliases` + `.blerc` (bash),
   `macos/.zshrc` (zsh), `windows/Microsoft.PowerShell_profile.ps1` (pwsh).
4. **Guard every tool** behind a presence check (`command -v` / `Get-Command`)
   so partial installs never break the shell.
5. **Never overwrite a user file without capturing the original first**, and
   capture it **once**. Use `deploy_file` in `Ubuntu24/scripts/common.sh` (or
   `Copy-Config` in `install.ps1`) — never a bare `install`/`cp`. `deploy_file`
   snapshots the original into `~/.local/state/cli_tweaks/pristine/` on the
   first install only, and keys that decision off the *manifest*, not off
   "does the file exist" — otherwise a second run captures our own config as if
   it were the user's original. (The pre-2026-07 `backup_file` helper did
   `mv file file.bak.<ts>` on every run and destroyed the real original.) On a
   machine that old helper already touched, `deploy_file` takes the **oldest**
   `<file>.bak` / `<file>.bak.*` beside the file as the original. `Copy-Config`
   moves the original to `*.bak.<ts>` only when the manifest does not know the
   path yet; later runs just overwrite.
5a. **The first manifest record wins.** "It is installed now" must never
   overwrite an earlier `preexisting: false` — on a re-run, what WE installed
   last time is present too. `apt_install_tracked`, `record_bin`, `record_font`
   and every `Register-*` in `install.ps1` keep an existing entry. Record an
   action **before** doing it (moving a file, writing a registry value), and
   `install.ps1` writes its manifest in a `finally`, so a failure halfway is
   still revertible.
6. Keep installers **componentised** with matching switches across platforms:
   `packages`, `fonts`, `starship`, `configs`, `alacritty` (+ `shell` on
   Windows for pwsh7, `blesh` on Ubuntu — Windows/macOS get inline
   autosuggestions from PSReadLine/zsh-autosuggestions and need no component).
   SSH is a planned, separate, manual step — not auto-installed.
7. **Every install component must be revertible.** Record what it did in the
   manifest and undo it in the platform uninstaller
   (`Ubuntu24/uninstall.sh`, `windows/uninstall.ps1`). Both refuse to touch
   anything flagged `preexisting` (packages, binaries, dirs, fonts, pwsh
   modules). Uninstallers must be **safe to repeat**: Ubuntu restores with
   `cp` from the pristine store; `uninstall.ps1` drops every reverted entry
   from the manifest, and never deletes a file whose recorded backup is
   missing (that file is most likely the already-restored original).

## Keep parity in sync

The same alias/function set must exist in all three shells (bash, zsh, pwsh).
When you touch one, touch the others (or explicitly note the gap in PARITY.md):

- `l` / `la` / `lss` (eza), `tree [depth]` + `tree1`..`tree9` (eza tree fn),
  `fin` (find from cwd), `c` (clear)
  — **never name a helper after a standard command** that does something
  *else*: the old `tr` function shadowed coreutils `tr`, breaking pipes and
  bash-completion scripts. `tree` is the deliberate exception — it replaces
  tree(1) with the same job, accepts its `-L`-style depth, and `command tree`
  still reaches the binary. Function-based shims must `unalias` first (an alias
  beats a function, and is expanded inside a re-sourced definition). In pwsh,
  also check `Get-Alias <name>`: built-in aliases beat functions (`gl` is
  `Get-Location` and must be removed first).
- `gs` / `gd` / `gl` (git), `top`/`htop` → btop
- fzf keybindings with an fd backend; UP/DOWN prefix history search
- zoxide `z` (canonical, still being rolled out — see PARITY drift notes)
- tmux helpers `t`/`ta`/`tk`/`tn` on Linux/macOS only (Windows has no tmux)
- the startup banner + `keys` cheatsheet (Ubuntu only so far — PLAN step 2).
  **When you add or change a macro or hotkey, update `keys` (and the banner if
  it is one of the headline ones)** in `Ubuntu24/configs/.bash_aliases` —
  otherwise the cheatsheet quietly lies. Spell keys as on the keyboard
  (`Ctrl+T`, `Alt+C`, `Shift+PgUp`, arrows as `← ↑ → ↓`), never `^T` / `M-c`.
  Keep the banner ≤ 78 columns. Pad with `__cli_tweaks_pad`, not
  `printf %-Ns`: bash's printf pads by BYTES, so arrows misalign.

## Environment / tooling gotchas

- There are **three dev machines**. Check which one you are on (`hostname`)
  before trusting the notes below.
  - **Ubuntu 24** (`SF-WS1181`): full coreutils, normal bash. Ubuntu changes
    can be tested here for real.
  - **Ubuntu 24.04 laptop** (`apavlyuk-IdeaPad-Slim-5-14IRH10`, Wayland): also
    real-testable, but no pwsh/zsh. As of 2026-10-05 it still runs an OLD
    pre-manifest deploy (`~/.bashrc.bak` and `~/.bash_aliases.bak` are the
    originals), ble.sh is not installed, and xclip is missing — a
    `--packages` run was interrupted.
  - **Windows 11**: the **Bash tool there lacks coreutils** (`find`, `mkdir`,
    `echo` fail) — use PowerShell or the dedicated file tools for filesystem
    work, not `bash -c`.
- **Bash `Tab` completion is order-sensitive**: `bash-completion` must be
  sourced *before* fzf's `completion.bash`. fzf hijacks ~35 commands and its
  fallback to the real completion only arms itself if `_completion_loader`
  already exists. Get it wrong and Tab dies in Alacritty/GNOME Terminal but
  keeps working in tmux (tmux starts a login shell, which loads
  bash-completion via `/etc/profile.d/` first). See `Ubuntu24/configs/.bashrc`.
- **ble.sh is loaded in two halves and the order is load-bearing.**
  `source ~/.local/share/blesh/ble.sh --attach=none` is the *first* thing in
  `Ubuntu24/configs/.bashrc`, `ble-attach` is the *last*. Everything in between
  (bash-completion, fzf, starship, `bind`) then registers through ble.sh's
  emulation layer rather than raw readline; starship checks `$BLE_VERSION` at
  init time to decide whether to hook via `blehook`. Nothing that binds keys or
  touches `PROMPT_COMMAND` may come after `ble-attach`. Under ble.sh, fzf must
  come from `ble-import -d integration/fzf-{completion,key-bindings}`, not from
  `/usr/share/doc/fzf/examples/key-bindings.bash` (kept as the fallback for a
  machine without ble.sh). Machine-local lines go in `~/.bashrc.local`, which
  `.bashrc` sources just before `ble-attach` and cli_tweaks never deploys or
  removes — don't tell users to append to `~/.bashrc` (the next `--configs`
  overwrites it).
- **The fzf `--exclude` list is duplicated** in `Ubuntu24/configs/.bashrc` and
  the Windows profile (`.git .vscode .vscode-shared .cache .config .local`).
  Change both.
- **ble.sh startup cost — keep it down.** Time to prompt: ~0.14 s without
  ble.sh, ~0.6 s with it (0.25 s load + 0.17 s `ble-attach`, inherent;
  measured on the laptop in power-saver mode). Three traps, all fixed:
  (1) every `ble-face` call costs ~1.5 ms — keep the palette in the
  `_blerc_faces` array and the single `ble-face "${_blerc_faces[@]}"` call,
  never add separate `ble-face` lines; (2) `char_width_mode/version=auto` (the
  default) makes every shell print `[▽] [▶] …` test characters and query the
  cursor — `.blerc` pins `west` / `15.1`; (3) any reinstall makes ble.sh's
  files newer than `~/.cache/blesh`, so each `$TERM` rebuilds its caches
  (`ble/term.sh: updating tput cache …`, ~1.7 s) — `install-blesh.sh` must not
  reinstall an existing ble.sh; updates go through `ble-update`. To measure,
  start `bash -i` in a detached tmux pane (it answers ble.sh's terminal
  queries; `script` does not) and time until the prompt appears.
- **ble.sh's settings live in `Ubuntu24/configs/.blerc`, not in `.bashrc`**
  (ble.sh sources `~/.blerc` by itself). That file holds the autosuggestion
  options and a full **Tokyo Night** face palette that overrides ble.sh's
  default one — the default (red builtins, hot-pink globs, white-on-red error
  blocks) was rejected as ugly. Keep any new colour in that palette: hue only,
  values taken from `shared/alacritty.toml`, no bold/underline/background
  blocks. The grey suggestion stays `fg=242` (approved) rather than a themed
  colour, so it reads as "not typed yet".
- **ble.sh keymap surgery has three traps** (all hit while making `Esc` cancel
  everywhere). *Timing*: every keymap is built lazily and its `define` drops
  anything bound earlier, so a bind straight from `.blerc` is silently ignored —
  `nsearch`/`isearch` must be bound in `blehook/eval-after-load keymap_emacs`,
  while `auto_complete`/`menu_complete` are already built when the `complete`
  hook runs and need `ble/function#advice after
  ble-decode/keymap:<name>/define`. *Key name*: bind `ESC`, `C-[` **and**
  `C-M-[` (two Esc bytes composed as Meta) — and none of them arrive at all
  without `bleopt decode_isolated_esc=esc`. A report of
  `unbound keyseq: C-M-[ C-M-[` means the shell predates the config: `~/.blerc`
  is read once, at shell start. The same key-name trap exists for the Backspace
  family: Ctrl+Backspace arrives as the byte 0x08 = key `C-h` (Alacritty, GNOME
  Terminal and tmux send nothing fancier), and Alt+Backspace (Esc + 0x7f)
  decodes as `C-M-?` — binding `M-DEL` alone looks right in `ble-bind -P` but
  never fires. Bind every alias, like `.blerc`'s word-delete loop does. *The mark*: with `_ble_edit_mark_active`
  set, the next character typed REPLACES the marked region — that is why the
  history-search wrappers in `.blerc` clear it.
- **tmux tabs live at the top.** `status 2` + `status-position top`: line 0
  is tmux's default tab list (styled via `window-status-*`), line 1 is
  `status-format[1]`, a hint line that switches by state (`client_prefix`,
  `pane_mode` copy-mode / tree-mode). Its texts are the `@hint-*` options —
  each ≤ 79 columns, pulled in with `#{@name}` so commas in the text cannot
  break the `#{?...}` around them. `message-line 1` puts prompts/messages on
  that line too. The right side drops user@host + date below 110 columns,
  otherwise it pushes the tabs off an 80-column window. tmux cannot split status
  lines between top and bottom. Root bindings `M-1..M-9` / `M-t` / `M-n`
  (rename) / `M-k` (close, with confirm) for tabs, and
  `M-arrows` (panes) are tmux's — don't bind those in ble.sh/zsh for use
  inside tmux. New panes/windows use `-c "#{pane_current_path}"`; keep that on
  any new split/new-window binding, including its Ukrainian twin.
- **Clipboard: never rely on OSC 52.** tmux's default `set-clipboard external`
  reaches Alacritty only under some `TERM` values (the "copies sometimes work"
  bug). Both tmux configs pipe copies through `xclip` (macOS: `pbcopy`), so
  **xclip is a dependency**, listed in `install-packages.sh`. Any new copy
  binding must be added to `copy-mode` *and* `copy-mode-vi` (tmux uses the -vi
  table only when `mode-keys` is vi; ours is emacs). In `.blerc`, write
  clipboard text with `ble/util/put` — `ble/util/print` appends a newline, which
  submits the line when pasted.
- **Alacritty + a Cyrillic layout**: bindings match the character the
  *active layout* produces, so `{ key = "V", mods = "Control|Shift" }` never
  fires on the Ukrainian layout (it is `М` there), and `Ctrl`/`Alt`+letter
  sent the Cyrillic letter instead of a control code. `shared/alacritty.toml`
  has a generated `[keyboard] bindings` block mapping every Ukrainian letter
  to the Latin key on the same cap (chars bindings carry
  `mode = "~Vi|~Search"`). Any new Alacritty binding on a letter needs its
  Cyrillic twin there too — and so does any new tmux prefix key (both
  `tmux.conf`s end with a "same keys on the Ukrainian layout" block; the
  layout is xkb `ua(unicode)`: `ґ` sits on the `\|` key, `ж` on `;`).
- **Pasting drops one trailing newline** (`.blerc`, advice on
  `ble/widget/bracketed-paste.proc`), so a triple-clicked line does not open
  ble.sh's MULTILINE mode.
- **Alacritty is not where autosuggestions live.** A terminal emulator cannot
  draw them; the line editor does. Grey-text bugs are ble.sh/`.bashrc` bugs.
- **Alacritty needs working OpenGL/GLX.** A `BadValue … BadAttribute` startup
  error is a GPU-driver fault, not a config fault — check `glxinfo -B` and
  `nvidia-smi` (a driver upgrade needs a reboot before the kernel module
  matches the userspace libs). Don't debug the TOML for this.
- Windows has **only Windows PowerShell 5.1** so far; pwsh7 is installed by
  `windows/install.ps1 -Shell`. The pwsh7 profile path is
  `~/Documents/PowerShell/profile.ps1` (NOT the `WindowsPowerShell` 5.1 path).
- Package manager on Windows: **winget** (choco also present; scoop absent).
  All winget IDs used are verified to exist; btop = `aristocratos.btop4win`
  (its command is `btop4win`, no `btop` shim).
- **`windows/install.ps1` and `uninstall.ps1` must stay ASCII-only** — they run
  under Windows PowerShell 5.1, which reads a no-BOM `.ps1` as ANSI and turns
  em-dashes/smart quotes into phantom string delimiters that break parsing. The
  pwsh7 **profile** may use non-ASCII (pwsh reads UTF-8). There is no pwsh on
  the Ubuntu machines, so `.ps1` edits made there are unparsed until run on
  Windows — say so.
- **`[regex]::Replace(...)` has no count overload.** A trailing `, 1` binds to
  `RegexOptions` (= IgnoreCase) and replaces *every* match. To replace only the
  first, use the instance method: `([regex]'pat').Replace($s, $repl, 1)`.
- **Install writes a manifest** (`%LOCALAPPDATA%\cli_tweaks\install-manifest.json`)
  recording packages (+ `preexisting` flag), deployed files + backups, modules
  and fonts (+ `preexisting`), and prior WT/terminal settings. `uninstall.ps1` reverts from it and
  **never removes anything flagged pre-existing**. Keep both in sync when you add
  an install component: record what it does in the manifest, revert it in uninstall.
- Alacritty's pwsh shell lives in `windows/alacritty-windows.toml` (overlay
  appended on deploy), NOT in `shared/alacritty.toml` (that would break Linux/macOS).

## Testing notes

- Windows changes can be tested on this machine (with the user's OK before
  installing software).
- macOS (and any future remote-hardware work) **cannot** be tested here — mark
  such changes as draft and call out that they need real-hardware validation.

## Style

Match the existing config style: heavy explanatory comments, clear section
banners, defensive guards. These are read by a human tweaking their own setup,
so readability beats cleverness.
