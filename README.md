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

## EFS persistence (Ona)

When `EFS_MOUNT_POINT` is set in your [Ona secrets](https://app.gitpod.io/settings/members?user-settings=secrets), the install script creates symlinks from `$HOME` into the EFS mount so credentials persist across instances.

What gets linked:

| Path | What it persists |
|------|-----------------|
| `~/.claude.json` | Claude Code OAuth + API key |
| `~/.claude/.credentials.json` | Claude Code credentials |
| `~/.config/gh/hosts.yml` | GitHub CLI auth |
| `~/.config/acli` | Atlassian CLI auth |
| `~/.aws` | AWS config |
| `~/.zsh_history` | Shell history |
| `~/.terminfo` | Ghostty terminfo |

Symlinks are created even if the mount isn't ready yet (dotfiles can run before `post-start.sh`). They resolve once EFS mounts.
