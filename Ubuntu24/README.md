
# My Ubuntu 24 cli tweaks

This repository contains my personal configuration files for Bash, Tmux, and Starship.

## Quick Install on a Fresh Ubuntu 24

### 1. Install Dependencies
First, update the system and install the required packages (`curl`, `git`, `tmux`, `tree`, and `fzf`):
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install curl git tmux tree fzf -y

```

### 2. Install Starship

Install the Starship cross-shell prompt:

```bash
curl -sS [https://starship.rs/install.sh](https://starship.rs/install.sh) | sh

```

### 3. Clone This Repository

Clone these dotfiles to your local machine (assuming you are cloning to `~/dotfiles`):

```bash
git clone https://github.com/kus-machine/cli_tweaks.git
cd Ubuntu24
```

### 4. Deploy the Configurations

Back up your default `.bashrc` just in case, then copy the new configs to their proper locations:

```bash
# Backup default bashrc
mv .bashrc ~/.bashrc.bak
mv .bash_aliases ~/.bash_aliases.bak

# Copy Bash and Tmux configs
cp .bashrc ~/.bashrc
cp .bash_aliases ~/.bash_aliases
cp .tmux.conf ~/.tmux.conf

# Create the config directory for Starship and copy the toml file
mkdir -p ~/.config
cp starship.toml ~/.config/starship.toml

```

### 5. Apply Changes

Reload your bash configuration to apply everything:

```bash
source ~/.bashrc
```

Your terminal should now be fully configured!
