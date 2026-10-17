# ---------------------------------------------------------------------------
# cli_tweaks -- "Open in <terminal>" in the Files (Nautilus) right-click menu.
#
# LEGACY, not maintained since 2026-10-18 (see README.md next to it).
# Deployed by  legacy/alacritty/install-alacritty.sh  to
#   ~/.local/share/nautilus-python/extensions/cli_tweaks_terminal.py
# Needs python3-nautilus (installed by the same script). Takes effect after
# `nautilus -q` (or logging out and in).
#
# Nautilus' own "Open in Terminal" belongs to the nautilus-extension-gnome-
# terminal package and ALWAYS opens GNOME Terminal, whatever the default is.
# This adds an item for the terminal that IS the default -- whatever the
# x-terminal-emulator alternative points at, read at click time, so
# installing the other terminal switches it without a restart.
#
# It stays out of the menu when that terminal already has an item of its own:
#   WezTerm      -- its package ships "Open in WezTerm" (wezterm-nautilus.py)
#   GNOME Term.  -- the stock "Open in Terminal"
# So in practice this is "Open in Alacritty".
# ---------------------------------------------------------------------------

import os

from gi.repository import GObject, Gio, Nautilus

ALTERNATIVE = '/etc/alternatives/x-terminal-emulator'

# realpath of the alternative -> (label, command that opens a folder | None)
# None = that terminal has its own menu item, add nothing.
KNOWN = {
    'alacritty':         ('Alacritty', lambda d: ['alacritty', '--working-directory', d]),
    'open-wezterm-here': None,
    'wezterm':           None,
    'gnome-terminal':    None,
    'gnome-terminal.wrapper': None,
}


def _default_terminal():
    """(label, argv builder) for the current default, or None."""
    target = os.path.basename(os.path.realpath(ALTERNATIVE))
    if target in KNOWN:
        return KNOWN[target]
    # Anything else: x-terminal-emulator started inside the folder.
    return (target, lambda d: ['x-terminal-emulator'])


class CliTweaksOpenTerminal(GObject.GObject, Nautilus.MenuProvider):

    def _item(self, name, path):
        term = _default_terminal()
        if term is None or not path:
            return []
        label, argv = term
        item = Nautilus.MenuItem(name=name, label='Open in ' + label)
        item.connect('activate', self._open, argv, path)
        return [item]

    def _open(self, _menu, argv, path):
        launcher = Gio.SubprocessLauncher.new(Gio.SubprocessFlags.NONE)
        launcher.set_cwd(path)
        launcher.spawnv(argv(path))

    @staticmethod
    def _folder(f):
        loc = f.get_location() if f.is_directory() else f.get_parent_location()
        return loc.get_path() if loc else None

    # Nautilus 4 passes (files) / (folder); 3.x passed the window first.
    def get_file_items(self, *args):
        files = args[-1]
        if len(files) != 1:
            return []
        return self._item('CliTweaks::open_terminal', self._folder(files[0]))

    def get_background_items(self, *args):
        return self._item('CliTweaks::open_terminal_here', self._folder(args[-1]))
