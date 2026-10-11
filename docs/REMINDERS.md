# Open reminders

Things the owner asked to be reminded about. **Claude: at the start of a
session, if this file has open items, mention them to the user in a line or
two before anything else** (see CLAUDE.md). Do not start fixing them unasked.
When an item is done, delete it (git history keeps the record); when the file
has no open items left, leave just this header.

---

## 1. Ubuntu installer / uninstaller safety fixes

_Added 2026-10-11 (review on the Windows box, code read only — nothing was run).
Fix and test **on an Ubuntu machine**; the Windows box cannot run these scripts._

Day-to-day Ubuntu use is not affected — these bite only on uninstall, on
re-runs, or on an interrupted install. Line numbers are as of `497c663`.

1. **`uninstall.sh --full` can remove packages that are not ours.**
   `uninstall.sh:187-188`: `apt-get remove -y <ours>` also removes every
   package that *depends* on ours (e.g. `git-lfs` / `tig` installed later,
   because we installed `git`), and `apt-get autoremove -y` then removes every
   orphaned package on the system, not just ours.
   Fix idea: simulate first (`apt-get -s remove …`), and if anything outside
   our list would go, list it and ask (or refuse). Drop the system-wide
   `autoremove`, or make it an explicit prompt.

2. **Any old `<file>.bak` is assumed to be the user's original.**
   `scripts/common.sh`, `oldest_backup_of` (used by `deploy_file`, ~line 124):
   a `~/.bashrc.bak` the user made by hand years ago becomes "the original",
   and uninstall restores that old file. Also install → `--full` → edit →
   install picks the first cycle's `.bak`.
   Fix idea: only accept the old helper's exact `.bak.YYYYmmdd_HHMMSS`
   pattern (or ask), and never overwrite an existing pristine copy.

3. **Re-running `--configs` silently overwrites edits.**
   `scripts/common.sh`, `deploy_file` (~lines 121-149): once a path is in the
   manifest, the next install writes straight over it. Hand edits to
   `.tmux.conf`, `.blerc`, `starship.toml`, `alacritty.toml` are lost (only
   `.bashrc` has an escape hatch: `.bashrc.local`). Same after
   install → `uninstall --configs` → install.
   Fix idea: if the current file differs from both the repo source and the
   pristine copy, save a `.bak.<ts>` first and say so.

4. **Manifest records come AFTER the action** (breaks CLAUDE.md rule 5a).
   - `scripts/install-blesh.sh` (~lines 62-65): an interrupted `--install`
     leaves `~/.local/share/blesh` unrecorded; the next run labels it
     `preexisting=true`, so it is never removed or repaired.
   - `scripts/common.sh`, `deploy_file` (~lines 147-149): interrupted between
     `install` and `manifest_add` → next run captures OUR file as the user's
     original.
   - `scripts/install-packages.sh` (~lines 39-45): a partial `tldr --update`
     cache dir is never recorded or retried.
   Fix idea: record `preexisting=false` / the pristine entry first, then act.

5. **`install-starship.sh:16` pipes curl into sh without `-f`.**
   `curl -sS https://starship.rs/install.sh | sh` — an HTTP error page or a
   truncated download is executed as a script. `--starship` alone also never
   ensures curl is installed, and `/usr/local/bin/starship` is hard-coded.
   Fix idea: `curl -fsSL` into a temp file, check the exit code, then run it;
   `apt_install_tracked curl` first; detect the binary path after install.

Smaller, same pass:
- `ensure_jq` (`common.sh:36-40`) installs jq without recording it, so it is
  later flagged `preexisting` and never removed; it also skips
  `apt-get update`, so `--fonts`/`--configs` alone can fail on a fresh image.
- `--full` leaves junk: empty `~/.local/share/fonts`, `~/.config/bat/themes`,
  `~/.config/alacritty`, `~/.cache/bat`, probably `~/.local/state/blesh`, and
  one more `.bak.<ts>` per install/uninstall cycle.
- `uninstall.sh` can stop halfway under `set -e` (e.g. `cp -a` into a deleted
  parent dir, missing `fc-cache`); re-running is safe.
