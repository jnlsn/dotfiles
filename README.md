# dotfiles

Personal dotfiles for Linux devcontainers and [Ona](https://ona.com/), managed with [GNU Stow](https://www.gnu.org/software/stow/).

```bash
git clone git@github.com:jnlsn/dotfiles.git ~/dotfiles
~/dotfiles/install.sh
```

Connect this repository under **Ona Settings > Preferences** to bootstrap new environments automatically. Installation requires Linux on x86_64 or aarch64. Missing system dependencies are installed with apt, using root or passwordless sudo; the installer never asks for a password.

## Packages

Each package mirrors `$HOME`. Stow links individual files into your home directory, keeping application-created state outside the checkout.

| Package | Configuration |
| --- | --- |
| `claude` | Claude Code settings and a modular session/Git/PR status line |
| `gh` | GitHub CLI preferences and `co` alias |
| `git` | Personal Git identity and global ignore patterns |
| `zellij` | Multiplexer keybindings and Kitty keyboard protocol |
| `zsh` | Oh My Zsh, plugins, PATH, NVM integration, and Ona secrets |

Neovim is no longer installed or managed. Zsh respects an existing `EDITOR`, defaulting to `vi`; GitHub CLI uses its normal editor selection. The installer backs up old configuration symlinks pointing into this repo's removed Neovim package, including dangling links. It leaves unrelated Neovim configurations and previously downloaded binaries/data alone.

Zsh loads Ona secrets, PATH, `EDITOR`, and `NVM_DIR` from `.zshenv`, including for non-interactive commands such as `zsh -c`. Oh My Zsh, plugins, and NVM initialization stay in `.zshrc` for interactive sessions. Bootstrap scripts load Ona secrets separately because they run in Bash.

## Startup lifecycle

### `install.sh`: tools and configuration

The installer:

1. Checks Linux/architecture and loads `/etc/profile.d/ona-secrets.sh` if available.
2. Checks for Git, curl, tar, Stow, Zsh, jq, Python 3, tomlkit, realpath, mountpoint, and flock; installs missing dependencies with apt.
3. Adds `~/.local/bin` to PATH before checking or installing tools.
4. Installs missing Zellij and pup binaries into `~/.local/bin`. Pup is used by the Datadog Claude plugin; failed optional downloads are reported and can be retried.
5. Migrates old repo-owned folded directory links, preserves conflicting files, runs Stow with `--no-folding --restow`, and merges portable Codex preferences.
6. Installs the `github/gh-stack` extension and its Claude Code skill when supported by the existing GitHub CLI. Missing `gh`, authentication, or skill support is reported without aborting setup.
7. Installs Oh My Zsh plus autosuggestions and syntax highlighting, and attempts to select Zsh without an interactive prompt.
8. Installs ACLI if `JIRA_API_TOKEN` is set and ACLI is missing.

It does **not** touch EFS or authenticate Jira. Claude Code, Codex, and GitHub CLI themselves are expected from your devcontainer image or separate installation.

### `post-start-install.sh`: persistence and Jira login

The Vanta Obsidian startup flow described in the [AI Workflows guide](https://docs.google.com/document/d/11jl0-TCg8Wd0qhV00J8AIE1YpVzKevH5fi8icjv4eto/edit) invokes this executable after the EFS mount step. This is an Obsidian lifecycle integration, not a universal Ona dotfiles hook. **A custom hook replaces the built-in EFS fallback**, so the list below is the complete persistence policy for this repo.

Set these Ona personal environment secrets as needed:

| Variable | Purpose |
| --- | --- |
| `EFS_MOUNT_POINT=/efs-home` | Optional existing EFS mount outside `$HOME` |
| `JIRA_API_TOKEN` | Optional personal Atlassian token; never commit its value |
| `JIRA_EMAIL` | Required for token-based setup; your Atlassian account email |
| `JIRA_SITE` | Optional, defaults to `vanta.atlassian.net` |

Remove legacy `USE_EFS_HOME` if present, then restart or create an environment to load changed secrets. Git's committed noreply address is deliberately **not** used for Jira authentication.

When EFS is enabled, post-start resolves the path, rejects relative paths and mounts inside or containing `$HOME`, checks that the path is an actual writable mount, and locks migrations across environments. A missing/unsafe mount stops the hook before persistence or login; local files remain untouched. Retry the hook after fixing the mount.

These paths are persisted:

- `~/.claude.json`
- `~/.claude/.credentials.json`
- `~/.config/gh/hosts.yml`
- `~/.config/acli`
- `~/.aws`
- `~/.zsh_history`
- `~/.codex/auth.json` — the rest of `~/.codex` stays local, following the guide's persistence correction.

On first migration, existing local data is copied to EFS and preserved locally as a backup before linking. If EFS already has a destination, it wins and the local version is backed up without overwriting it. No fake credential files are created: a link can be dangling until the relevant tool initializes its data. The health check reports these absent targets.

This mount must be private to your account. Local backups may also contain credentials. EFS is scoped to your runner region and GitHub user; the guide states there are no service backups. Retain an independent copy of important data. Shared authentication does not guarantee concurrent application writes are safe; the lock protects this hook's migrations only.

Jira login runs after persistence, or with local state when EFS is unset. Existing authenticated sessions are left alone. Login uses a private temporary token file, suppresses command output, and removes the file on success, failure, or handled interruption. Browser-based agent sign-in remains interactive.

For a running environment, or a devcontainer without the Obsidian hook:

```bash
cd ~/dotfiles
git pull
./install.sh
# Run only after the configured EFS mount is ready (or with EFS unset):
./post-start-install.sh
./doctor.sh
```

## Codex preferences

`codex/` is installed separately from Stow because Codex also writes local configuration and runtime state. The bootstrap uses `/usr/bin/python3` and the apt package `python3-tomlkit` to merge TOML while retaining comments and unrelated settings.

- `codex/config.toml` manages only `tui.status_line`: model/reasoning, directory, Git branch, context usage, and permissions. Other TUI options, model selection, approval policy, MCP servers, profiles, project trust, and hook state are preserved.
- `codex/instructions.md` becomes a marked section of your global `AGENTS.md`: concise communication and PR descriptions, focused changes, proportionate verification, and completing authorized work. Existing text outside that section is preserved.
- Changed files receive numbered private backups before atomic replacement. Reruns with no changes do not write files or create backups. Invalid TOML or malformed instruction markers stop setup before either file is changed.
- The target defaults to `~/.codex`, respecting an existing `CODEX_HOME`. Individual file symlinks are converted to local files without modifying their source; a symlinked entire Codex directory is rejected. Authentication, sessions, and databases are not managed by this installer.

Edit the repo templates and rerun `install.sh` to update managed preferences. You can also install or check just these preferences with a Python environment containing tomlkit:

```bash
/usr/bin/python3 codex/install.py
/usr/bin/python3 codex/install.py --check
```

Start a new Codex session to load updated instructions. A nonempty `AGENTS.override.md` takes precedence; the installer reports it and leaves it alone. Auth-only EFS persistence still targets `~/.codex/auth.json`; a custom `CODEX_HOME` needs its own persistence decision.

The installer does not import third-party skills, model/context overrides, telemetry, or MCP integrations. Configuration follows the official [config reference](https://learn.chatgpt.com/docs/config-file/config-reference) and [AGENTS.md guidance](https://learn.chatgpt.com/docs/agent-configuration/agents-md).

## File preservation and Stow migration

Conflicts are renamed to `.bak`, `.bak.1`, `.bak.2`, etc.; earlier backups and dangling backup symlinks are never overwritten.

Older installs may have linked whole directories such as `~/.claude` or `~/.config/gh` into this repo. `lib/prepare-stow.py` converts repo-owned directory links into real home directories, keeps tracked configuration linked, and moves untracked runtime files out of the checkout into those directories. It preserves the old directory link as a numbered backup. Those backup links are recovery references, not frozen copies of managed configuration.

Unrelated directory symlinks are rejected rather than followed or replaced. Resolve those manually before rerunning. Runtime credential/skill paths are also excluded from Stow and Git as a fallback for older checkouts.

## Health checks and tests

`./doctor.sh` is read-only. It checks expected commands, GitHub/Jira authentication, tracked Stow links, Codex preferences, folded directories, mount health, persistence links, and absent targets. It prints no credential contents and performs no login or repair. Exit status is 1 when checks need attention, including optional tools that are missing.

Regression tests exercise missing mounts, conflicting persistent data, failed copies, backup collisions, repeat runs, folded-directory migrations, and removal of repo-owned Neovim links. Fixtures and mocks use temporary directories; they do not run the real installer or alter your home. When GNU Stow is on PATH, an additional integration test checks real Stow migration and reruns.

```bash
# Use a Python environment with tomlkit for the Codex merge tests.
python3 -m unittest discover -s tests -v
for script in install.sh post-start-install.sh doctor.sh lib/common.sh; do
    bash -n "$script" || exit
done
zsh -n zsh/.zshenv
zsh -n zsh/.zshrc
```

After deployment, run the health check in Ona and verify credential reuse in a second environment in the same region.

## Updates and personal preferences

Rerunning the installer installs missing tools and refreshes config links; it does **not** upgrade tools already on PATH. New Zellij/pup installs use the latest release by default. Set `ZELLIJ_VERSION` or `PUP_VERSION` to an exact upstream release tag to choose a version for a fresh install. These overrides do not replace existing binaries. ACLI uses its latest Linux release for a missing install.

Upgrade binaries deliberately using their supported update process, then run `doctor.sh`. Update the extension with `gh extension upgrade gh-stack` and its skill with `gh skill update` when supported. Oh My Zsh and its plugins have separate update lifecycles; bootstrap does not pull their repositories on reruns.

- Git identity is personal and committed: change `git/.config/git/config` when forking.
- `gh` uses SSH for Git operations, so configure an SSH key separately. `GH_TOKEN` can supply CLI authentication without a stored `hosts.yml` credential.
- Claude defaults to Opus with thinking enabled. Review its permission-prompt settings and enabled plugins (`frontend-design`, `code-review`, `pup`, and `superpowers`) for your environment.
- Zsh uses the agnoster theme, which expects a Powerline-compatible font. NVM is loaded only if already installed.
- Zellij uses Option+Shift+Arrow or Alt+h/j/k/l for pane movement and Alt+Shift+f for floating panes, preserving shell word-navigation shortcuts.

To change configuration, edit the repo or the linked live file. To add a package, add its files to Git and add its name to `PACKAGES` in `lib/common.sh`, then rerun installation. The migration and health check use Git's tracked-file list.

To remove current configuration links:

```bash
cd ~/dotfiles
stow --no-folding -D -t "$HOME" claude gh git zellij zsh
```

This leaves backups, application data, and EFS persistence links in place.
