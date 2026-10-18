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

**Open reminders:** at the start of every session, read
[docs/REMINDERS.md](docs/REMINDERS.md). If it lists open items, remind the user
of them in a line or two (title + where to fix) before doing anything else, and
don't start on them unless asked. Delete an item there once it is done.

**Git: the owner commits and pushes, not you.** Never run `git commit` or
`git push` (nor amend, tag, or anything else that writes history or the remote)
unless the user explicitly asks you to commit and push in that conversation.
By default, only propose a commit message. **Never add an AI attribution
trailer** (`Co-Authored-By: Claude …`, "Generated with Claude Code", or
similar) to commit messages or PR descriptions — this rule overrides any tool
or harness default that says otherwise.

## Golden rules

1. **Ubuntu24 is the canonical experience.** When adding a feature, define it in
   the Ubuntu configs + PARITY.md first, then propagate to other platforms.
2. **Portable configs live in `shared/`** (starship, wezterm, bat themes, lesskey). Platform
   installers *reference* them; never copy a shared file into a platform folder.
   If you change where a shared file lives, update every installer that reads it
   (currently: `Ubuntu24/scripts/install-{starship,wezterm,configs}.sh`,
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
   `packages`, `fonts`, `starship`, `configs`, and the terminal `wezterm`
   (part of `--all`; on Ubuntu it also becomes the default — Ctrl+Alt+T +
   Files menu, `install-default-terminal.sh` — there is deliberately no
   separate "default terminal" flag) (+ `shell` on Windows for pwsh7, `blesh` on
   Ubuntu — Windows/macOS get inline autosuggestions from
   PSReadLine/zsh-autosuggestions and need no component).
   SSH is a planned, separate, manual step — not auto-installed.
6a. **`legacy/` is parked, not maintained.** Ubuntu offered Alacritty (+ tmux
   for tabs) as a second terminal until 2026-10-18; the owner dropped it as
   double work and parked it in `legacy/alacritty/` to maybe try again. Do not
   update those files for new keys/colours, and do not wire them back into
   `install.sh`. tmux itself is NOT legacy (ssh, detach) — keep its config,
   its Ukrainian twins and the `@only tmux` block of `keys` current.
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
- tmux helpers `t`/`ta`/`tk`/`tn` on Linux/macOS only (Windows has no tmux;
  WezTerm's tabs/panes take the tmux keys there — `shared/wezterm.lua`)
- the startup banner + `keys` cheatsheet (Ubuntu + Windows; zsh still to do).
  **When you add or change a macro or hotkey, update `keys` (and the banner if
  it is one of the headline ones)** — Ubuntu: the heredoc + banner rows in
  `Ubuntu24/configs/.bash_aliases`; Windows: `windows/keys.txt` + the `$rows`
  of `cli_tweaks_banner` in the pwsh profile (and `HINTS` in `wezterm.lua`
  for WezTerm keys). A `wezterm.lua` key also lives in the `@only wezterm`
  block of Ubuntu's `keys` — otherwise the cheatsheet quietly lies. Spell keys as on the keyboard
  (`Ctrl+T`, `Alt+C`, `Shift+PgUp`, arrows as `← ↑ → ↓`), never `^T` / `M-c`.
  Keep the banner ≤ 78 columns. Pad with `__cli_tweaks_pad`, not
  `printf %-Ns`: bash's printf pads by BYTES, so arrows misalign.

## Environment / tooling gotchas

- There are **three dev machines**. Check which one you are on (`hostname`)
  before trusting the notes below.
  - **Ubuntu 24** (`SF-WS1181`): full coreutils, normal bash. Ubuntu changes
    can be tested here for real.
  - **Ubuntu 24.04 laptop** (`apavlyuk-IdeaPad-Slim-5-14IRH10`, Wayland): also
    real-testable, but no pwsh/zsh. Since 2026-10-04 it has a manifest; its
    pristine store holds the old pre-manifest originals (`~/.bashrc.bak`,
    `~/.bash_aliases.bak`). ble.sh, xclip and WezTerm (as the default
    terminal) are installed. `sudo` asks for a password, so the Bash tool
    cannot run steps that need it — the owner runs those.
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
  values as listed in `legacy/alacritty/alacritty.toml` (= WezTerm's
  `Tokyo Night`), no bold/underline/background
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
- **tmux + a Cyrillic layout**: the key after the prefix arrives as the
  Cyrillic letter, so any new tmux prefix key needs its Ukrainian twin (both
  `tmux.conf`s end with a "same keys on the Ukrainian layout" block; the
  layout is xkb `ua(unicode)`: `ґ` sits on the `\|` key, `ж` on `;`). WezTerm
  needs no twins (physical keys). The legacy Alacritty config solved the same
  problem with a generated `[keyboard] bindings` block — see
  `legacy/alacritty/` if it is ever revived.
- **Pasting drops one trailing newline** (`.blerc`, advice on
  `ble/widget/bracketed-paste.proc`), so a triple-clicked line does not open
  ble.sh's MULTILINE mode.
- **WezTerm on Ubuntu vs ble.sh.** The wezterm package's
  `/etc/profile.d/wezterm.sh` is bash-preexec (PROMPT_COMMAND + DEBUG trap),
  sourced by the login shell BEFORE `.bashrc` loads ble.sh — `wezterm.lua`
  sets `WEZTERM_SHELL_SKIP_ALL=1` on Linux, and `.bashrc` sends the OSC 133
  marks itself with `blehook PRECMD`/`PREEXEC` (before `ble-attach`). On Linux,
  `wezterm.lua` also sends every unbound Ctrl/Alt+letter by its physical key,
  so the Ukrainian layout still gets `Ctrl+R`, `Alt+C` (Windows' console does
  that on its own). It also sets `enable_wayland = false`: on GNOME Wayland
  the nightly drew no title bar at all (no _ □ X, no resize); through
  XWayland GNOME draws the normal one. `Ctrl+B ?` runs `keys --stay` from a plain `bash -c`.
- **A release upgrade switches the WezTerm apt repo off.** `do-release-upgrade`
  (even one that aborts, as on the laptop 2026-10-17) renames
  `/etc/apt/sources.list.d/wezterm.list` to `wezterm.list.distUpgrade`, and
  `wezterm-nightly` silently stops updating. `install.sh --wezterm` does NOT
  repair it: with the package installed it skips the repository step. Move
  the file back by hand (`sudo mv … .distUpgrade … .list`); `apt-cache
  policy wezterm-nightly` should list `apt.fury.io`.
- **`uninstall.sh --full` never runs `apt-get autoremove`** and never removes
  a package blindly: each of ours is simulated first (`apt-get -s`, no root
  needed) and kept if it would take a non-ours package along; only orphans
  that OUR removal creates go. The old `autoremove -y` would have taken 21
  NVIDIA driver packages on SF-WS1181. Test it with `--dry-run`, or in a fake
  `$HOME` with a logging `sudo` stub first on `PATH`.
- **The terminal is not where autosuggestions live.** A terminal emulator cannot
  draw them; the line editor does. Grey-text bugs are ble.sh/`.bashrc` bugs.
- **GPU terminals need working OpenGL.** WezTerm (and the legacy Alacritty)
  fail on a GPU-driver fault, not a config fault — check `glxinfo -B` and
  `nvidia-smi` (a driver upgrade needs a reboot before the kernel module
  matches the userspace libs). Don't debug the config for this. Alacritty
  said `BadValue … BadAttribute`; WezTerm's window flashes and closes, and
  `wezterm start` prints `egl Initialize: BAD_ACCESS` (2026-10-13:
  unattended-upgrades had moved the NVIDIA libs to 580.178 under a running
  580.173 kernel module — `nvidia-smi` says `Driver/library version
  mismatch`; a reboot fixes it).
- The Windows box was reset by hand on 2026-10-11: no cli_tweaks tools, but
  **PowerShell 7 is installed** (kept); pwsh7 is otherwise installed by
  `windows/install.ps1 -Shell`. The pwsh7 profile path is
  `~/Documents/PowerShell/profile.ps1` (NOT the `WindowsPowerShell` 5.1 path);
  its data files go to `~/.config/cli_tweaks/` (`keys.txt`, `lesskey`).
- **The pwsh profile has a startup budget (~0.2 s).** The first Windows setup
  took ~5 s. Never import a module eagerly (PSFzf is loaded on the first
  Ctrl+T/R/Alt+C; posh-git was dropped), and never spawn a process at start —
  `starship init` / `zoxide init` go through `__ct_cached_init` (cached in
  `%LOCALAPPDATA%\cli_tweaks\cache`). Measure with
  `$env:CLI_TWEAKS_TIMING=1; pwsh` before and after a change.
- **The pwsh profile must force the console to UTF-8** (`[Console]::OutputEncoding`
  and `::InputEncoding` near the top, guarded by `-not IsOutputRedirected`).
  Without it the console falls back to the legacy OEM code page, so typing on
  the Ukrainian (or any non-Latin) layout echoes `?????` and Nerd Font /
  box-drawing glyphs break. Control keys (Ctrl/Alt+letter) still work — they
  are control codes, not text, so "shortcuts fine, letters are `?`" points
  straight here. bash on Ubuntu gets this from the locale, so this is
  Windows-only.
- **PSReadLine names a Ctrl+letter key by the console's CURRENT keyboard
  layout** — at bind time and at press time. Started on the Ukrainian layout,
  `-Key Ctrl+d` is filed as `Ctrl+в` (`Get-PSReadLineKeyHandler -Bound` shows
  it under that name, so a filter on `Ctrl+d` finds "nothing"); Ctrl+D on the
  English layout then prints `^D`, and Ctrl+R hits PSReadLine's built-in
  search (its defaults are always filed under the Latin name). `Alt+c` is
  the reverse: filed Latin, arrives as `Alt+с`. `__ct_twin_keys` at the end
  of the pwsh profile files every Ctrl/Alt+letter under both names (Latin +
  the Cyrillic letter on the same cap) by reflection into PSReadLine's
  `_dispatchTable` (tested on 2.4.5; wrapped in `try`); a script-block
  binding beats a built-in one. Bind new letter keys BEFORE it; anything
  that rebinds later (PSFzf's import) must call it again. Do NOT "fix" this
  in `wezterm.lua` with the physical-key `SendKey` loop on Windows — tried
  2026-10-18: one press arrived twice, Alt+C typed `c`, typing hung.
- **starship's prompt silently kills zoxide's directory recording.** zoxide's
  generated pwsh init hooks by WRAPPING the `prompt` function, but the profile's
  fallback prompt and then starship both REPLACE `prompt` outright (both defined
  after the zoxide block), so the wrapper is lost: the database never fills and
  `z foo` matches nothing. The profile records on every `cd` via
  `$ExecutionContext.SessionState.InvokeCommand.LocationChangedAction` instead —
  prompt-independent, so it survives whoever owns the prompt. Re-check this if
  the prompt wiring is ever reordered.
- **starship's `format` must not end with a newline** (`shared/starship.toml`,
  last line ends with `\`): bash's `$(...)` strips it, pwsh prints it and the
  cursor lands on the line below the `▸`.
- **WezTerm (Windows) key rules**, all from the owner: **no `Ctrl+Shift+…`
  bindings** (Ctrl+Shift switches the keyboard layout); every key as
  `phys:` with `key_map_preference = 'Physical'`, so the Ukrainian layout needs
  no twins; on-screen labels (Ctrl+B q, quick-select) are **digits**; leader
  `Ctrl+B` with a 5 s timeout plus direct Alt keys; normal title bar
  (`TITLE|RESIZE` — integrated buttons render as a dot/dash with the Nerd
  Font). WezTerm is the **nightly** (official zip, see below); stable is 2024-02.
- fzf on Windows runs `--preview` commands through **cmd.exe**: use `2>NUL`
  and `||`, not bash syntax. PSFzf reads `FZF_CTRL_T_OPTS` / `FZF_ALT_C_OPTS`
  / `FZF_CTRL_R_OPTS`, and runs `FZF_ALT_C_COMMAND` via Invoke-Expression.
- winget: **MSI packages (starship) fail a silent uninstall without admin**
  (exit 1603); winget's exit codes are unreliable (non-zero for "already
  installed") — judge by `winget list`; portable packages leave **dead user
  PATH entries** behind. `uninstall.ps1` handles all three.
- **WezTerm crashing on start with `panic at …dwrote…font_collection.rs`**
  (log in `~\.local\share\wezterm\`) = Windows' DirectWrite font cache still
  points at font files that were replaced while loaded (e.g. `install.ps1
  -Fonts` over an older FiraCode). Not a config bug — `wezterm -n ls-fonts`
  works, with the config it panics. Sign out/in (or restart). The installer
  prints a NOTE when it replaced font files.
- WezTerm on Windows is NOT installed via winget: `wez.wezterm.nightly` pins
  one build's hash while its URL serves the newest nightly ("Installer hash
  does not match"). `install.ps1 -WezTerm` unpacks the official nightly zip to
  `%LOCALAPPDATA%\Programs\WezTerm` + a Start menu shortcut instead.
- **WezTerm start on Windows** (measured 2026-10-18): ~0.6 s to a window is
  WezTerm itself (renderer / GPU settings change nothing); `wsl_domains = {}`
  in `wezterm.lua` saves the ~0.25 s it spent asking wsl.exe for distros on
  every window — keep it, WSL is a static `launch_menu` entry. **Don't give
  the Start-menu shortcut a `Ctrl+Alt+T` "Shortcut key"**: Explorer waits a
  fixed ~3 s before starting the program. Ctrl+Alt+T is a by-hand PowerToys
  Keyboard Manager remap (`windows/README.md`).
- **A slow COLD WezTerm start on Windows is Windows Defender**, not WezTerm,
  pwsh or the profile (2026-10-18). The nightly `wezterm-gui.exe` is unsigned
  (68 MB); Defender re-checks it after a boot or a signature update, and a
  launch waits for the verdict — a never-seen copy took 2.2 s vs 0.6 s,
  the first launch after a boot 13 s before WezTerm even ran, while pwsh +
  profile + first prompt stayed ~0.6 s (`CLI_TWEAKS_TIMING` shows that chain).
  A second launch during the wait blocks on the same verdict. Ruled out:
  stale `gui-sock-*` files, the AMD iGPU (WezTerm renders with OpenGL on the
  RTX), renderer settings. The fix would be a Defender exclusion for
  `wezterm-gui.exe` — the owner declined it; don't add one or suggest it again
  unasked.
- A tool that cannot reach the network with **os error 10013** (e.g.
  `tldr --update`) is blocked by the owner's firewall, not broken.
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
- Windows does not use Alacritty any more (WezTerm since 2026-10-12); the old
  `windows/alacritty-windows.toml` overlay is gone. `uninstall.ps1` still
  reverts an Alacritty recorded by an older manifest (generic package/file
  entries).

## Testing notes

- **CI runs on every push** (`.github/workflows/check.yml`, GitHub Actions):
  shellcheck at warning level, bash/zsh syntax, both `tmux.conf` load, TOML /
  Lua / lesskey syntax, the ASCII rule for `install.ps1` / `uninstall.ps1`,
  their parse under 5.1 (read as ANSI) and pwsh 7, and
  `tests/ubuntu-configs-roundtrip.sh` (install/uninstall `--configs` in a
  throwaway `$HOME`, no sudo). Run that test locally after touching
  `deploy_file`, `install-configs.sh` or `uninstall.sh`. A new script or
  config file must be added to `check.yml`, or nothing checks it.

- Windows changes can be tested on this machine (with the user's OK before
  installing software).
- macOS (and any future remote-hardware work) **cannot** be tested here — mark
  such changes as draft and call out that they need real-hardware validation.

## Style

Match the existing config style: heavy explanatory comments, clear section
banners, defensive guards. These are read by a human tweaking their own setup,
so readability beats cleverness.
