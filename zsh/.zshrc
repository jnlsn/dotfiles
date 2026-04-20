export PATH="$HOME/.local/bin:$HOME/bin:/opt/homebrew/opt/libpq/bin:$PATH"

export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="agnoster"
HYPHEN_INSENSITIVE="true"
COMPLETION_WAITING_DOTS="true"

plugins=(git z brew copypath macos npm sudo zsh-autosuggestions zsh-syntax-highlighting)

source $ZSH/oh-my-zsh.sh

# Disable meta-sends-escape (mode 1034) over SSH — fixes double-character
# rendering in Ghostty when TERM=xterm-ghostty on the remote.
[[ -n "$SSH_TTY" ]] && printf '\e[?1034l'

export EDITOR='vim'

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
export PATH="$HOME/.local/bin:$PATH"
