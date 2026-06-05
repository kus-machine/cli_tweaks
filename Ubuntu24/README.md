
# My Ubuntu 24 cli tweaks

This repository contains my personal configuration files for Bash, Tmux, and Starship.

## Quick Install on a Fresh Ubuntu 24

### Install Dependencies
First, update the system and install the required packages (`curl`, `git`, `tmux`, `tree`, and `fzf`):
```bash
sudo apt update
sudo apt install curl git tmux eza tree fzf fd-find ripgrep btop -y

```

### Install icons for eza:
```bash
mkdir -p ~/.local/share/fonts
wget https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip
unzip FiraCode.zip -d ~/.local/share/fonts/
fc-cache -fv
rm FiraCode.zip
```

### Install Starship

Install the Starship cross-shell prompt:

```bash
curl -sS https://starship.rs/install.sh | sh

```

### Clone This Repository

Clone these dotfiles to your local machine:

```bash
git clone https://github.com/kus-machine/cli_tweaks.git
cd Ubuntu24
```

### Deploy the Configurations

Back up your default `.bashrc` just in case, then copy the new configs to their proper locations:

```bash
# Backup default bashrc
mv ~/.bashrc ~/.bashrc.bak
mv ~/.bash_aliases ~/.bash_aliases.bak

# Copy Bash and Tmux configs
cp .bashrc ~/.bashrc
cp .bash_aliases ~/.bash_aliases
cp .tmux.conf ~/.tmux.conf

# Create the config directory for Starship and copy the toml file
mkdir -p ~/.config
cp starship.toml ~/.config/starship.toml

```

### Apply Changes

Reload your bash configuration to apply everything:

```bash
source ~/.bashrc
```

Your terminal should now be fully configured!




### Optional: Install & Configure **Alacritty** Terminal

If you want a fast, GPU-accelerated terminal with native transparency, you can install Alacritty.

**1. Install Alacritty:**

```bash
sudo apt install alacritty -y
```

**2. Set as System Default:**
Run the following command and enter the selection number for `/usr/bin/alacritty` to make it your default terminal:

```bash
sudo update-alternatives --config x-terminal-emulator
```

**3. Deploy the Configuration:**
Copy the provided configuration file from this repository to your system:

```bash
mkdir -p ~/.config/alacritty
cp alacritty.toml ~/.config/alacritty/alacritty.toml
```

**4. Customize:**
Open `~/.config/alacritty/alacritty.toml` in your preferred text editor to modify the configuration. You can adjust settings like background opacity (`opacity = 0.85`), colors, and font sizes. Changes will apply automatically the moment you save the file.