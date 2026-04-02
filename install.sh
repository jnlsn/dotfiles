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

info "Stowing dotfiles ($PACKAGES)..."
cd "$DOTFILES"
stow -t ~ $PACKAGES
ok "All packages stowed"
