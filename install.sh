#!/bin/bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
OS="$(uname -s)"

info() { printf '\033[34m[info]\033[0m %s\n' "$1"; }
skip() { printf '\033[33m[skip]\033[0m %s\n' "$1"; }
ok()   { printf '\033[32m[ ok ]\033[0m %s\n' "$1"; }

# Package manager setup & GNU Stow
if [ "$OS" = "Darwin" ]; then
    if ! command -v brew &>/dev/null; then
        info "Installing Homebrew..."
        NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        eval "$(/opt/homebrew/bin/brew shellenv)"
        ok "Homebrew installed"
    else
        skip "Homebrew already installed"
    fi

    if ! command -v stow &>/dev/null; then
        info "Installing GNU Stow..."
        brew install stow
        ok "Stow installed"
    else
        skip "Stow already installed"
    fi
else
    if ! command -v stow &>/dev/null; then
        info "Installing GNU Stow..."
        sudo apt-get update -qq && sudo apt-get install -y -qq stow
        ok "Stow installed"
    else
        skip "Stow already installed"
    fi
fi

# Oh My Zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    info "Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    ok "Oh My Zsh installed"
else
    skip "Oh My Zsh already installed"
fi

# zsh-autosuggestions
if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ]; then
    info "Installing zsh-autosuggestions..."
    git clone https://github.com/zsh-users/zsh-autosuggestions "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
    ok "zsh-autosuggestions installed"
else
    skip "zsh-autosuggestions already installed"
fi

# zsh-syntax-highlighting
if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ]; then
    info "Installing zsh-syntax-highlighting..."
    git clone https://github.com/zsh-users/zsh-syntax-highlighting "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"
    ok "zsh-syntax-highlighting installed"
else
    skip "zsh-syntax-highlighting already installed"
fi

# Stow packages — only stow macOS-specific packages on Darwin
PACKAGES="claude gh git zsh"
if [ "$OS" = "Darwin" ]; then
    PACKAGES="$PACKAGES ghostty vscode"
fi

# Back up existing files that would conflict with stow symlinks
# (e.g. .zshrc and .zprofile created by the devcontainer base image)
for pkg in $PACKAGES; do
    for f in "$DOTFILES/$pkg"/.*; do
        [ -e "$f" ] || continue
        target="$HOME/$(basename "$f")"
        if [ -f "$target" ] && [ ! -L "$target" ]; then
            info "Backing up $target to $target.bak"
            mv "$target" "$target.bak"
        fi
    done
done

info "Stowing dotfiles ($PACKAGES)..."
cd "$DOTFILES"
stow -t ~ $PACKAGES
ok "All packages stowed"

# Set zsh as default shell
if [ "$(getent passwd "$(id -un)" | cut -d: -f7)" != "/usr/bin/zsh" ]; then
    info "Setting default shell to zsh..."
    sudo chsh "$(id -un)" --shell "/usr/bin/zsh"
    ok "Default shell set to zsh"
else
    skip "Default shell already zsh"
fi

# EFS network directory — persist credentials across Ona instances.
# Set EFS_MOUNT_POINT in Ona secrets to enable (e.g. /efs).
# Docs: https://docs.google.com/document/d/1sypPRmiGrbh4g2UmbkNNLo8ELKG7mSK_Avs7vyx2KPk
EFS_DIR="${EFS_MOUNT_POINT:-}"
if [ -n "$EFS_DIR" ] && [ -d "$EFS_DIR" ]; then
    info "EFS mount detected at $EFS_DIR — linking credentials..."

    # Links a file or directory from $HOME to $EFS_DIR. Migrates existing
    # content on first run, then creates a symlink for future instances.
    link_to_efs() {
        local name="$1"
        local src="$HOME/$name"
        local dst="$EFS_DIR/$name"

        # Already correct
        if [ -L "$src" ] && [ "$(readlink "$src")" = "$dst" ]; then
            return
        fi

        # Migrate existing file/dir to EFS if destination doesn't exist yet
        if [ ! -e "$dst" ] && [ -e "$src" ] && [ ! -L "$src" ]; then
            mkdir -p "$(dirname "$dst")"
            mv "$src" "$dst"
        fi

        # Remove stale real file/dir or wrong symlink at src
        if [ -e "$src" ] || [ -L "$src" ]; then
            rm -rf "$src"
        fi

        mkdir -p "$(dirname "$src")"
        mkdir -p "$(dirname "$dst")"
        ln -s "$dst" "$src"
    }

    link_to_efs ".claude.json"              # Claude Code OAuth + API key
    link_to_efs ".claude/.credentials.json"  # Claude Code credentials
    link_to_efs ".config/gh/hosts.yml"       # GitHub CLI auth
    link_to_efs ".config/acli"               # Atlassian CLI auth
    link_to_efs ".aws"                       # AWS config
    link_to_efs ".zsh_history"               # Shell history
    link_to_efs ".terminfo"                  # Ghostty terminfo

    ok "EFS credential symlinks configured"
else
    skip "No EFS mount found (set EFS_MOUNT_POINT in Ona secrets to enable)"
fi
