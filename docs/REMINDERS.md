# Open reminders

Things the owner asked to be reminded about. **Claude: at the start of a
session, if this file has open items, mention them to the user in a line or
two before anything else** (see CLAUDE.md). Do not start fixing them unasked.
When an item is done, delete it (git history keeps the record); when the file
has no open items left, leave just this header.

---

## 1. Ubuntu installer safety fixes (install side)

_Added 2026-10-11 (review on the Windows box). The **uninstall** half was fixed
and sandbox-tested on SF-WS1181 on 2026-10-12 (apt simulation instead of
`autoremove`, record-before-act in deploy_file / ble.sh / tldr, jq recorded,
repeat-safe, empty dirs pruned, pristine copy reused after `--full`). Left:_

1. **Any old `<file>.bak` is assumed to be the user's original.**
   `scripts/common.sh`, `oldest_backup_of` (used by `deploy_file`): a
   `~/.bashrc.bak` the user made by hand years ago becomes "the original".
   Careful: on the laptop `~/.bashrc.bak` / `~/.bash_aliases.bak` ARE the
   originals, so plain `.bak` cannot simply be dropped — ask, or show the
   candidate and its date.

2. **Re-running `--configs` silently overwrites edits.**
   `deploy_file`: once a path is in the manifest, the next install writes
   straight over it. Hand edits to `.tmux.conf`, `.blerc`, `starship.toml`,
   `wezterm.lua` are lost (only `.bashrc` has an escape
   hatch: `.bashrc.local`).
   Fix idea: if the current file differs from both the repo source and the
   pristine copy, save a `.bak.<ts>` first and say so.

3. **`install-starship.sh` pipes curl into sh without `-f`.**
   `curl -sS https://starship.rs/install.sh | sh` — an HTTP error page or a
   truncated download is executed as a script. `--starship` alone also never
   ensures curl is installed, and `/usr/local/bin/starship` is hard-coded.
   Fix idea: `curl -fsSL` into a temp file, check the exit code, then run it;
   `apt_install_tracked curl` first; detect the binary path after install.

4. **SF-WS1181's own manifest** says `~/.bash_aliases` and `~/.tmux.conf` had
   no original (`pristine: null`), so `uninstall.sh --configs` there DELETES
   them. The real old `.tmux.conf` is probably
   `~/.tmux.conf.bak.20260608_154748` (owned by root, 756 bytes). Decide, then
   copy it into the pristine store and fix the manifest entry by hand.

5. **`install-wezterm.sh` never repairs a missing apt source.**
   _Added 2026-10-18._ With `wezterm-nightly` installed it skips the
   repository step, so a `wezterm.list` disabled by a release upgrade (see
   CLAUDE.md) stays off. Fix idea: if the manifest records the source as ours
   and it is missing, put it back (and drop a `wezterm.list.distUpgrade`).

---

## 2. Windows leftovers after the `wezterm_dev` merge

_`wezterm_dev` was validated on Windows and Ubuntu and merged into `main` on
2026-10-18 (git history has the full record). Do these **on the Windows box**._

1. **Not eyeballed yet:** `alert` (OSC 777 -> toast; PARITY.md).
2. **pwsh startup is over budget:** `$env:CLI_TWEAKS_TIMING=1; pwsh` showed
   ~0.47 s, starship ~0.37 s of it, against the ~0.2 s target.
3. **Small installer leftovers:** `uninstall.ps1 -Cosmetic` removes the
   WezTerm Start-menu shortcut (an install artifact); every
   `-SetDefaultTerminal` run piles up another `settings.json.bak.<ts>`;
   `-Starship` prints "already present - will not be removed" although the
   manifest correctly keeps it as ours.
4. Delete `C:\Users\pawla\cli_tweaks_cleanup_20261011_224657\` (quarantine
   of the old install; `cleanup.log` maps every file) — nothing in it is
   needed now that the new install works.
