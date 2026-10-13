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
   `alacritty.toml`, `wezterm.lua` are lost (only `.bashrc` has an escape
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

---

## 2. Windows: validate branch `wezterm_dev`, then merge

_Added 2026-10-12. The owner had no time to test; everything was pushed on
their go-ahead. Do this **on the Windows box**._

The WezTerm + pwsh setup was hand-tested in a trial folder; the repo version
(`windows/install.ps1`, `uninstall.ps1`, profile, `wezterm.lua` — moved to
`shared/wezterm.lua` on 2026-10-12 and given Linux branches, `keys.txt`,
`shared/lesskey`, the `shared/starship.toml` newline fix) has only been
parse-checked and load-tested, never installed for real.

0. **First remove the trial's traces**, or the install will record them as
   `preexisting` and uninstall will never remove them: close WezTerm, delete
   `C:\Users\pawla\cli_tweaks_trial\` and `~\.local\share\wezterm`, and
   unregister the 18 `FiraCodeNerdFont*` fonts the trial re-registered
   (files in `%LOCALAPPDATA%\Microsoft\Windows\Fonts`, values under
   `HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts`). PowerShell 7
   stays (it predates this and is correctly `preexisting`).
1. From **Windows PowerShell 5.1**: `cd windows; ./install.ps1 -All`
   (UAC prompts for the MSI packages are expected). Read the manifest it wrote.
2. Open WezTerm and walk the checklist in `windows/README.md` ("After
   installing"): banner, `keys` / Ctrl+B ?, Alt/Ctrl+B pane keys, Ctrl+B y,
   starship (cursor right after `▸`, red on failure), Ctrl+T/Ctrl+R/Alt+C
   with previews, `z`, F1, `alert`, `less` keys on the Ukrainian layout.
   `$env:CLI_TWEAKS_TIMING=1; pwsh` should show ~0.2 s.
3. `./uninstall.ps1 -Full -WhatIf`, then `-Cosmetic` twice for real, then
   `./install.ps1 -Configs` again (manifest bookkeeping across re-runs).
4. If all good: merge `wezterm_dev` into `main`, update PARITY.md's
   "not eyeballed" cells.
5. Then delete `C:\Users\pawla\cli_tweaks_cleanup_20261011_224657\`
   (quarantine of the old install; `cleanup.log` maps every file) — nothing
   in it is needed once the new install works.
