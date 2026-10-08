# Shared environment for interactive and non-interactive Zsh sessions.
# Keep prompts, plugins, completion, and runtime initialization in .zshrc.
if [[ -r /etc/profile.d/ona-secrets.sh ]]; then
  source /etc/profile.d/ona-secrets.sh
fi

typeset -U path
path=("$HOME/.local/bin" "$HOME/bin" $path)
export PATH

export EDITOR="${EDITOR:-vi}"
export NVM_DIR="$HOME/.nvm"
