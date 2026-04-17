# dotfiles

Personal dotfiles for macOS and Linux, managed with [GNU Stow](https://www.gnu.org/software/stow/). The install script bootstraps a fresh machine (or [Ona](https://ona.com/)/Gitpod cloud devcontainer) into a working environment with one command.

## Quick start

```bash
git clone git@github.com:dustin-riley/dotfiles.git ~/dotfiles
~/dotfiles/install.sh
```

The script is idempotent — safe to re-run after pulling updates.

## How Stow works (if you haven't seen it)

Each top-level directory in this repo is a **package** laid out as a mirror of `$HOME`. For example, `zsh/.zshrc` → `~/.zshrc`, and `vscode/Library/Application Support/Code/User/settings.json` → `~/Library/Application Support/Code/User/settings.json`.

`stow` creates symlinks from `$HOME` back into this repo. Edits you make to your live config are edits to the repo — commit them and they're tracked.

If a real file already exists where a symlink needs to go (common on devcontainer base images that ship a `.zshrc`), the install script renames it to `*.bak` before stowing, so you never lose data silently.

## Packages

| Package    | Manages                                            | Target                                                        | Platform |
| ---------- | -------------------------------------------------- | ------------------------------------------------------------- | -------- |
| `claude`   | Claude Code settings (model, status line, plugins) | `~/.claude/settings.json`                                     | all      |
| `gh`       | GitHub CLI config (aliases, protocol, editor)      | `~/.config/gh/config.yml`                                     | all      |
| `git`      | Git identity + global gitignore                    | `~/.config/git/config`, `~/.config/git/ignore`                | all      |
| `ghostty`  | Terminal config (theme, padding, cursor, keys)     | `~/Library/Application Support/com.mitchellh.ghostty/config`  | macOS    |
| `vscode`   | Editor settings (formatting, TS, exclusions)       | `~/Library/Application Support/Code/User/settings.json`       | macOS    |
| `zellij`   | Terminal multiplexer config (keybinds, kitty kbd)  | `~/.config/zellij/config.kdl`                                 | all      |
| `zsh`      | Shell config (Oh My Zsh, plugins, PATH, NVM)       | `~/.zshrc`, `~/.zprofile`                                     | all      |

Linux installs omit `ghostty` and `vscode` (macOS-only targets).

### Notable config choices

- **Git identity is committed.** `git/.config/git/config` hard-codes `Dustin Riley` and a GitHub `noreply` email as the global identity. If you fork this, change it before running `install.sh` or your commits will be attributed to me.
- **`gh` uses SSH**, not HTTPS. You'll need an SSH key registered with GitHub before `gh` clones/pushes work.
- **Claude Code runs Opus by default** with `alwaysThinkingEnabled: true` and `skipDangerousModePermissionPrompt: true`. The latter disables the dangerous-mode confirmation prompt, which is fine in ephemeral cloud devcontainers but is a conscious trust tradeoff on a personal laptop. Review `claude/.claude/settings.json` and decide for yourself.
- **Enabled Claude plugins:** `frontend-design`, `code-review`, and `pup` (from the `datadog-labs/pup` marketplace). These are fetched by Claude Code itself, not by `install.sh`.
- **VS Code** enables format-on-save with Prettier, auto-runs ESLint fixes and import organization on save, and turns on the experimental TypeScript Go server (`typescript.experimental.useTsgo`).
- **Ghostty** uses the `Birds of Paradise` theme and binds `shift+enter` to send a literal escape+CR (useful for multi-line input in REPLs/TUIs that treat bare Enter as submit). `macos-option-as-alt = left` remaps Left Option to Alt, leaving Right Option free for macOS special characters (∆, ˚, ¬). Option+Arrow is overridden to send CSI modifier-3 sequences (`\e[1;3{A,B,C,D}`) instead of Ghostty's default readline word-nav (`ESC b` / `ESC f`) — otherwise zellij decodes Option+Right as `Alt+f` (ToggleFloatingPanes) instead of `Alt+Right` (MoveFocus).
- **Zellij** enables the Kitty keyboard protocol (`support_kitty_keyboard_protocol true`) for clean modifier-key disambiguation.

## What `install.sh` actually does

Read the script — it's ~170 lines and stays that way deliberately. But since it modifies a fresh system, here's what to expect before you run it:

### Always installs

1. **GNU Stow** (via Homebrew on macOS, apt on Linux).
2. **Zellij** (terminal multiplexer). On macOS, via Homebrew. On Linux, the script downloads the latest release tarball from GitHub into `~/.local/bin/zellij` — it does **not** use apt, so there's no system-wide install and no `sudo` needed for this step.
3. **Oh My Zsh** (via the official installer, unattended mode).
4. **zsh-autosuggestions** and **zsh-syntax-highlighting** (cloned into `~/.oh-my-zsh/custom/plugins/`).

### macOS only

- **Homebrew**, if missing. Installed non-interactively — will prompt for your password via `sudo` during Homebrew's own installer.

### Linux only

- **Changes your default shell to zsh** using `sudo chsh`. Skipped if zsh is already default. This is why `install.sh` may prompt for `sudo`.

### Opinionated decisions worth flagging

- **Zellij is installed unconditionally**, including on Ona instances. It's not wired into `.zshrc` as auto-start, so nothing changes unless you invoke `zellij`, but the binary will be on disk. If you don't want it, delete the Zellij block in `install.sh` before running.
- **Conflicting dotfiles are renamed to `.bak`**, not deleted. If `~/.zshrc` exists as a regular file, it becomes `~/.zshrc.bak` and the stow symlink takes over. Re-running the installer won't overwrite an existing `.bak` — so if you re-bootstrap twice, the oldest backup is what sticks around.
- **`PATH` precedence** (from `zsh/.zshrc`): `~/.local/bin` → `~/bin` → `/opt/homebrew/opt/libpq/bin` → system. Anything you drop into `~/.local/bin` (including the Linux-installed Zellij) wins over Homebrew and system binaries.
- **SSH TTY fix:** `.zshrc` disables terminal mode 1034 (`meta-sends-escape`) over SSH. This is a workaround for Ghostty's `xterm-ghostty` `TERM` causing double-character rendering on remote hosts. Harmless if you don't use Ghostty.

## Ona / Gitpod

### Auto-bootstrapping a new instance

Ona has a **dotfiles repo** setting (under user settings → dotfiles). Point it at this repo and Ona will clone it and run `install.sh` automatically on every new instance. Combined with the EFS persistence below, a fresh instance comes up fully configured with credentials intact — no manual steps.

### EFS persistence

Cloud devcontainers are ephemeral — credentials wiped on every new instance is painful. `install.sh` has an opt-in mode that symlinks auth-bearing files from `$HOME` onto a persistent mount so they survive across instances.

**How to enable it:** set an environment variable named `EFS_MOUNT_POINT` to the path where your persistent volume is mounted (e.g. `/efs`). In Ona, add it under user settings → [secrets/environment variables](https://app.gitpod.io/settings/members?user-settings=secrets) so it's exported into every new instance automatically. `install.sh` reads it at runtime; if it's unset, the EFS step is skipped.

**Recommended value:** a dedicated path like `/efs` — **not** `$HOME` or a subdirectory of it. Pointing it at the home directory would be self-referential (the script links files in `$HOME` *to* `$EFS_MOUNT_POINT`) and would break the script. The intent is a small, deliberate set of files you carry between instances; everything else should stay ephemeral so instances remain clean and reproducible.

### What gets linked

| Path                           | Why                                       |
| ------------------------------ | ----------------------------------------- |
| `~/.claude.json`               | Claude Code OAuth token + API key         |
| `~/.claude/.credentials.json`  | Claude Code credentials                   |
| `~/.config/gh/hosts.yml`       | GitHub CLI auth                           |
| `~/.config/acli`               | Atlassian CLI auth                        |
| `~/.aws`                       | AWS SDK config + credentials              |
| `~/.zsh_history`               | Shell history                             |

### Timing

`install.sh` may run before the EFS volume is actually mounted (e.g. before `post-start.sh`). That's fine — the script creates the symlinks regardless, and they resolve correctly once the mount is ready. The first instance to run against an empty EFS migrates any existing local file over before symlinking; subsequent instances just symlink.

### Security note

The linked paths contain live credentials. EFS here is assumed to be private to your user account. Don't point `EFS_MOUNT_POINT` at anything shared with other humans.

## Modifying and iterating

- **Edit a config:** edit the file in this repo (or edit the symlinked target — same thing) and commit.
- **Add a new package:** create a top-level directory mirroring `$HOME`, add it to the `PACKAGES` list in `install.sh`, and re-run `install.sh`.
- **Unstow everything:** `cd ~/dotfiles && stow -D -t ~ claude gh git zellij zsh` (add `ghostty vscode` on macOS). Symlinks go away; your `.bak` files remain where you left them.
- **Check what's linked:** `ls -la ~ | grep dotfiles` shows which files in `$HOME` point back here.

## Repo layout

```
.
├── install.sh              # bootstrap (macOS + Linux, idempotent)
├── claude/                 # Claude Code settings
├── gh/                     # GitHub CLI
├── git/                    # git identity + global ignore
├── ghostty/                # Ghostty terminal (macOS)
├── vscode/                 # VS Code (macOS)
├── zellij/                 # Zellij (terminal multiplexer)
└── zsh/                    # zsh + Oh My Zsh
```
