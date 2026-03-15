#!/bin/bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")" && pwd)"

info() { printf '\033[34m[info]\033[0m %s\n' "$1"; }
skip() { printf '\033[33m[skip]\033[0m %s\n' "$1"; }
ok()   { printf '\033[32m[ ok ]\033[0m %s\n' "$1"; }

# Homebrew
if ! command -v brew &>/dev/null; then
    info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
    ok "Homebrew installed"
else
    skip "Homebrew already installed"
fi

# GNU Stow
if ! command -v stow &>/dev/null; then
    info "Installing GNU Stow..."
    brew install stow
    ok "Stow installed"
else
    skip "Stow already installed"
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

# Stow all packages
info "Stowing dotfiles..."
cd "$DOTFILES"
stow -t ~ claude gh ghostty git vscode zsh
ok "All packages stowed"
