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

**Progress 2026-10-17 (on the Windows box):** steps 0, 1 and the `-WhatIf` half
of 3 are DONE. Trial traces removed and the manifest fixed so the 18 fonts +
both WezTerm dirs are now `preexisting:false` (ours); `uninstall.ps1 -Full
-WhatIf` confirmed it now reverts configs, fonts (files + registry), packages
and `Programs\WezTerm`, keeping PowerShell 7. Two profile bugs found while
eyeballing and fixed (uncommitted): console not forced to UTF-8 (Ukrainian
typed as `?????`) and zoxide's hook killed by starship's prompt (`z` never
matched) — see the new CLAUDE.md gotchas. Left: the owner's visual checklist
(step 2), the real teardown/rebuild (step 3 below), then merge.

0. ✅ DONE. Trial traces removed (`cli_tweaks_trial`, `~\.local\share\wezterm`,
   the 18 `FiraCodeNerdFont*` files + HKCU values), manifest surgery dropped
   the stale `preexisting` entries, and `install.ps1 -Fonts -WezTerm` re-recorded
   them as ours. PowerShell 7 stays (correctly `preexisting`).
1. ✅ DONE (as `-Configs -WezTerm -Fonts`, pwsh7 — no 5.1/UAC needed since the
   tools were already installed from the earlier 2026-10-15 run). Manifest read
   back and verified.
2. **Owner, in WezTerm:** walk the checklist in `windows/README.md` ("After
   installing"): banner, `keys` / Ctrl+B ?, Alt/Ctrl+B pane keys, Ctrl+B y,
   starship (cursor right after `▸`, red on failure), Ctrl+T/Ctrl+R/Alt+C
   with previews, **Ukrainian letters type correctly (not `?????`)**, **`z`
   jumps after a couple of `cd`s**, F1, `alert`, `less` keys on the Ukrainian
   layout. `$env:CLI_TWEAKS_TIMING=1; pwsh` (was ~0.47 s here, starship ~0.37 s
   of it — over the ~0.2 s target, worth a look).
3. `-WhatIf` done. Still to do for real: `./uninstall.ps1 -Cosmetic` twice,
   then `./install.ps1 -Configs` again (manifest bookkeeping across re-runs).
4. If all good: merge `wezterm_dev` into `main`, update PARITY.md's
   "not eyeballed" cells.
5. Then delete `C:\Users\pawla\cli_tweaks_cleanup_20261011_224657\`
   (quarantine of the old install; `cleanup.log` maps every file) — nothing
   in it is needed once the new install works.
