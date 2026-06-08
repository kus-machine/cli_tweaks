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

chmod +x install.sh
chmod +x scripts/*.sh
```

## Available Components

### --packages

Installs useful command-line tools:

- git
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

Existing files are automatically backed up with timestamps.

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

## Activate Bash Changes

```bash
source ~/.bashrc
```