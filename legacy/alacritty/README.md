# legacy/alacritty — not maintained

Until 2026-10-18 the Ubuntu installer offered two terminals: **Alacritty**
(tabs and panes from tmux) or **WezTerm** (tabs and panes built in, the same
setup as on Windows). Keeping both meant every key change in three to four
places (`wezterm.lua`, `.tmux.conf` + its Ukrainian twins, the Cyrillic block
here, both halves of `keys`), so Ubuntu now has WezTerm only. The Alacritty
part is parked here in case it is worth another try one day.

**Nobody keeps these files in step with the rest of the repo.** New keys,
colours or fixes land in `shared/wezterm.lua` and the shell configs, not here.

| File | What it was |
|---|---|
| `alacritty.toml` | the config (was `shared/alacritty.toml`): Tokyo Night, FiraCode, the generated `[keyboard] bindings` block that maps every Ukrainian letter to the Latin key on the same cap |
| `install-alacritty.sh` | installs Alacritty + that config + the Files-menu item, recorded in the manifest (was `Ubuntu24/scripts/install-alacritty.sh`) |
| `cli_tweaks_terminal.py` | "Open in Alacritty" in the Files right-click menu (was `Ubuntu24/configs/nautilus/`) |

**tmux is not legacy.** It stays installed and configured
(`Ubuntu24/configs/.tmux.conf`) for SSH and sessions that must outlive the
window; WezTerm's launcher (`Ctrl+B l`) starts it.

## Trying it again

```bash
legacy/alacritty/install-alacritty.sh
sudo update-alternatives --set x-terminal-emulator /usr/bin/alacritty   # Ctrl+Alt+T
nautilus -q                                                             # menu item
```

`Ubuntu24/uninstall.sh --configs` reverts it like any other component (the
script writes to the same manifest). Expect drift: the cheatsheet (`keys`)
shows the tmux keys inside Alacritty, but any key added after 2026-10-18 has
no Cyrillic twin in `alacritty.toml`.

The colour values in `alacritty.toml` are still the reference for the Tokyo
Night palette used by `.blerc`, `.tmux.conf` and the banner.
