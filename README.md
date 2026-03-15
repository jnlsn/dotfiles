# dotfiles

Personal dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/).

## What's included

| Package | Manages | Target |
|---------|---------|--------|
| `claude` | Claude Code settings (model, status line, plugins) | `~/.claude/settings.json` |
| `gh` | GitHub CLI config (aliases, protocol, editor) | `~/.config/gh/config.yml` |
| `ghostty` | Terminal config (padding, cursor style) | `~/.config/ghostty/config` |
| `git` | Global gitignore | `~/.config/git/ignore` |
| `vscode` | Editor settings (formatting, linting, TypeScript) | `~/Library/Application Support/Code/User/settings.json` |
| `zsh` | Shell config (Oh My Zsh, plugins, PATH) | `~/.zshrc`, `~/.zprofile` |

## Setup

```bash
git clone git@github.com:dustin-riley/dotfiles.git ~/dotfiles
~/dotfiles/install.sh
```

The install script checks for and installs any missing prerequisites (Homebrew, GNU Stow, Oh My Zsh, zsh plugins), then stows all packages. Safe to re-run.
