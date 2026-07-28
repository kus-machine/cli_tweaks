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
cd cli_tweaks

chmod +x install.sh uninstall.sh
chmod +x scripts/*.sh
```

## Available Components

### --packages

Installs useful command-line tools:

- bash-completion (required — see [Tab completion](#tab-completion))
- git
- jq (used to track what the installer changes)
- tmux
- eza
- tree
- fzf
- fd
- ripgrep
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

Your original files are captured **once**, on the first install, into
`~/.local/state/cli_tweaks/pristine/` (plus one timestamped `.bak` beside the
file). Re-running the installer does not pile up further backups.

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
apt-removes only the packages whose manifest entry says `preexisting: false`.

The pristine copies are deliberately kept after `--full`, so a later re-install
still has your real originals to fall back on. Delete
`~/.local/state/cli_tweaks/` by hand if you want them gone.

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