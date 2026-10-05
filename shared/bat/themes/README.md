# bat themes

Extra colour themes for [bat](https://github.com/sharkdp/bat) (`cat` with
syntax highlighting; it also draws the fzf `Ctrl+T` preview). Shared across
platforms: `.tmTheme` is bat's own portable format.

| File | Theme name in bat | From | License |
|---|---|---|---|
| `tokyonight_night.tmTheme` | `tokyonight_night` — **the default** (`BAT_THEME` in `.bashrc`) | [folke/tokyonight.nvim](https://github.com/folke/tokyonight.nvim), `extras/sublime/` | Apache-2.0, [`LICENSE.tokyonight`](LICENSE.tokyonight) |
| `synthwave84.tmTheme` | `synthwave84` | [lucasvscn/synthwave-sublime](https://github.com/lucasvscn/synthwave-sublime), converted from Robb Owen's [SynthWave '84](https://github.com/robb0wen/synthwave-vscode) | MIT, [`LICENSE.synthwave84`](LICENSE.synthwave84) |

Both files are unmodified copies. `Ubuntu24/scripts/install-configs.sh`
deploys them to `~/.config/bat/themes/` and rebuilds bat's theme cache
(`bat cache --build`); `uninstall.sh` removes them and rebuilds / clears the
cache again. A theme's name in bat is its file name without `.tmTheme`.

Try another one for a single command: `bat --theme=synthwave84 FILE`; list all
with `bat --list-themes`.
