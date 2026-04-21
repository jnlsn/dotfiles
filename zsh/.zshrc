export PATH="$HOME/.local/bin:$HOME/bin:/opt/homebrew/opt/libpq/bin:$PATH"

# Fall back to xterm-256color when the host's terminfo database doesn't
# know xterm-ghostty (common on Ona/Gitpod, Debian/Ubuntu ≤ ncurses 6.4).
# Without a matching terminfo entry, zsh-autosuggestions and
# zsh-syntax-highlighting can't redraw the prompt line correctly and every
# keystroke appears duplicated. Must run before oh-my-zsh loads so plugins
# initialise against the resolved TERM.
if [[ "$TERM" == "xterm-ghostty" ]] && ! infocmp xterm-ghostty &>/dev/null; then
  export TERM=xterm-256color
fi

export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="agnoster"
HYPHEN_INSENSITIVE="true"
COMPLETION_WAITING_DOTS="true"

plugins=(git z brew copypath macos npm sudo zsh-autosuggestions zsh-syntax-highlighting)

source $ZSH/oh-my-zsh.sh

export EDITOR='vim'

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
export PATH="$HOME/.local/bin:$PATH"
