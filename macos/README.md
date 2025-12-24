# Zsh Profile Setup

Setup instructions for a fresh macOS (M1/M2/M3) environment.

### 1. Install Homebrew
```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```


### 2. Install Dependencies

Install all tools and plugins used in .zshrc.

```
brew install eza tree tmux zsh-autosuggestions zsh-syntax-highlighting fzf zoxide
```

#### Additionally, install tools:
```
brew install bat tree
```

### 3. Configure FZF
Generate the required ***~/.fzf.zsh*** keybindings file.


```
$(brew --prefix)/opt/fzf/install
```


### 4. Install Config

Copy your configuration to the home directory.


```
nano ~/.zshrc
nano ~/.tmux.conf
```

# Paste the content -> Save (Ctrl+O) -> Exit (Ctrl+X)


### 5. Apply Changes

```
source .zshrc && exec zsh
```