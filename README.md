# dotfiles

Personal dotfiles for Linux devcontainers, managed with [GNU Stow](https://www.gnu.org/software/stow/). The install script bootstraps a fresh instance (or [Ona](https://ona.com/)/Gitpod cloud devcontainer) into a working environment with one command.

## Quick start

```bash
git clone git@github.com:jnlsn/dotfiles.git ~/dotfiles
~/dotfiles/install.sh
```

The script is idempotent — safe to re-run after pulling updates.

## How Stow works (if you haven't seen it)

Each top-level directory in this repo is a **package** laid out as a mirror of `$HOME`. For example, `zsh/.zshrc` → `~/.zshrc`, and `gh/.config/gh/config.yml` → `~/.config/gh/config.yml`.

`stow` creates symlinks from `$HOME` back into this repo. Edits you make to your live config are edits to the repo — commit them and they're tracked.

If a real file already exists where a symlink needs to go (common on devcontainer base images that ship a `.zshrc`), the install script renames it to `*.bak` before stowing, so you never lose data silently.

## Packages

| Package    | Manages                                            | Target                                              |
| ---------- | -------------------------------------------------- | --------------------------------------------------- |
| `claude`   | Claude Code settings (model, status line, plugins) | `~/.claude/settings.json`                           |
| `gh`       | GitHub CLI config (aliases, protocol, editor)      | `~/.config/gh/config.yml`                           |
| `git`      | Git identity + global gitignore                    | `~/.config/git/config`, `~/.config/git/ignore`      |
| `nvim`     | Neovim config (lazy.nvim, LSP, treesitter)         | `~/.config/nvim/`                                   |
| `zellij`   | Terminal multiplexer config (keybinds, kitty kbd)  | `~/.config/zellij/config.kdl`                       |
| `zsh`      | Shell config (Oh My Zsh, plugins, PATH, NVM)       | `~/.zshrc`                                          |

### Notable config choices

- **Git identity is committed.** `git/.config/git/config` hard-codes the global identity. If you fork this, change it before running `install.sh` or your commits will be attributed to the wrong person.
- **`gh` uses SSH**, not HTTPS. You'll need an SSH key registered with GitHub before `gh` clones/pushes work.
- **Claude Code runs Opus by default** with `alwaysThinkingEnabled: true` and `skipDangerousModePermissionPrompt: true`. The latter disables the dangerous-mode confirmation prompt, which is fine in ephemeral cloud devcontainers but is a conscious trust tradeoff. Review `claude/.claude/settings.json` and decide for yourself.
- **Enabled Claude plugins:** `frontend-design`, `code-review`, and `pup` (from the `datadog-labs/pup` marketplace). The plugins themselves are fetched by Claude Code; the `pup` binary they shell out to is installed by `install.sh`.
- **Neovim** is configured with [lazy.nvim](https://github.com/folke/lazy.nvim) as the plugin manager. `init.lua` sets the leader (space) then loads three modules from `lua/config/` (`options`, `keymaps`, `lazy`); every file under `lua/plugins/` returns a plugin spec that lazy auto-imports. Batteries included: treesitter, LSP (via `mason` — `lua_ls`, `pyright`, `ts_ls`, `gopls`, `rust_analyzer`, and more auto-installed on first launch), `nvim-cmp` completion, telescope (`<leader>ff` files, `<leader>fg` grep), neo-tree (`<leader>fe`), gitsigns, and the tokyonight colorscheme. `EDITOR` and the `gh` editor both point at `nvim`, and `.zshrc` aliases `vim`/`vi` → `nvim`. First launch clones lazy.nvim and installs plugins, so it needs network and takes a minute; subsequent launches are instant. lazy writes a `lazy-lock.json` into the config dir — commit it if you want reproducible plugin versions across instances.
- **Zellij** enables the Kitty keyboard protocol (`support_kitty_keyboard_protocol true`) so modifier-key combos like Option+Shift+Arrow encode distinctly. Pane navigation is bound to **Option+Shift+Arrow** (and `Alt+h/j/k/l`), not plain Option+Arrow — the latter is reserved for shell word-nav. `ToggleFloatingPanes` is `Alt+Shift+f` for the same reason (plain `Alt+f` collides with word-forward `ESC f`).

## What `install.sh` actually does

Read the script — it's ~200 lines and stays small deliberately. But since it modifies a fresh system, here's what to expect before you run it:

1. **GNU Stow** (via apt).
2. **Zellij** (terminal multiplexer). Downloads the latest release tarball from GitHub into `~/.local/bin/zellij` — no system-wide install and no `sudo` needed for this step.
3. **Neovim** — downloads the latest stable release tarball from GitHub into `~/.local/nvim/` and symlinks the binary to `~/.local/bin/nvim` (no `sudo`, no system-wide install). The apt package is usually too old for the Lua/LSP APIs this config uses, hence the release download.
4. **Pup** (Datadog CLI) to `~/.local/bin/pup` from the latest GitHub release, if missing. The `pup` Claude plugin's agents all shell out to the binary, so skipping this makes them non-functional.
5. **`gh stack`** — installs the [`github/gh-stack`](https://github.com/github/gh-stack) GitHub CLI extension for stacked branches/PRs. Requires `gh` on `PATH` and an authenticated `gh`; both are skipped with a warning rather than failing the install.
6. **The `gh-stack` agent skill** for Claude Code, at user scope (`~/.claude/skills/gh-stack/`), so Claude knows how to drive `gh stack` in every repo. Needs `gh` new enough to have the preview `gh skill` command (2.9x+); older releases are skipped with a warning. Update it later with `gh skill update`.
7. **Oh My Zsh** (via the official installer, unattended mode).
8. **zsh-autosuggestions** and **zsh-syntax-highlighting** (cloned into `~/.oh-my-zsh/custom/plugins/`).
9. **Changes your default shell to zsh** using `sudo chsh`. Skipped if zsh is already default. This is why `install.sh` may prompt for `sudo`.
10. **Auto-authenticates ACLI** if `JIRA_API_TOKEN` is set in the environment — see [ACLI auth](#acli-auth).

### Opinionated decisions worth flagging

- **Zellij is installed unconditionally**, including on Ona instances. It's not wired into `.zshrc` as auto-start, so nothing changes unless you invoke `zellij`, but the binary will be on disk. If you don't want it, delete the Zellij block in `install.sh` before running.
- **Stacked PRs go through `gh stack`**, not Graphite. The extension keeps its state in `.git/gh-stack` per repo (uncommitted), so there's nothing for stow to link — run `gh stack init` in a repo the first time you want a stack there. Neither the extension nor its skill is stow-managed: they're per-machine state under `~/.local/share/gh/extensions/` and `~/.claude/skills/`, installed imperatively by `install.sh`.
- **The `gh-stack` skill install must stay ahead of the stow step** in `install.sh`. It creates `~/.claude/skills/`, which keeps `~/.claude` a real directory so stow can't fold the whole of `~/.claude` into a single symlink back into this repo. Reorder those two and, on a box with no pre-existing `~/.claude`, the skill files land in the repo's working tree instead of `$HOME`.
- **Conflicting dotfiles are renamed to `.bak`**, not deleted. If `~/.zshrc` exists as a regular file, it becomes `~/.zshrc.bak` and the stow symlink takes over. Re-running the installer won't overwrite an existing `.bak` — so if you re-bootstrap twice, the oldest backup is what sticks around.
- **`PATH` precedence** (from `zsh/.zshrc`): `~/.local/bin` → `~/bin` → system. Anything you drop into `~/.local/bin` (including the installed Zellij) wins over system binaries.

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
| `~/.config/acli`               | Atlassian CLI non-secret config (site, email) — token lives in the OS keyring, see [ACLI auth](#acli-auth) |
| `~/.aws`                       | AWS SDK config + credentials              |
| `~/.zsh_history`               | Shell history                             |

### Timing

`install.sh` may run before the EFS volume is actually mounted (e.g. before `post-start.sh`). That's fine — the script creates the symlinks regardless, and they resolve correctly once the mount is ready. The first instance to run against an empty EFS migrates any existing local file over before symlinking; subsequent instances just symlink.

### Security note

The linked paths contain live credentials. EFS here is assumed to be private to your user account. Don't point `EFS_MOUNT_POINT` at anything shared with other humans.

### ACLI auth

ACLI stores its OAuth/API token in the OS keyring (libsecret via DBus), not on disk — so even with `~/.config/acli` linked to EFS, every fresh Ona instance boots logged out. The fix is a non-interactive re-auth on each boot using a long-lived API token.

**How to enable it:** create an API token at <https://id.atlassian.com/manage-profile/security/api-tokens> and set `JIRA_API_TOKEN` in Ona secrets (same place you set `EFS_MOUNT_POINT`). `install.sh` will then run `acli jira auth login --token` on every instance. Optional overrides: `JIRA_EMAIL` (defaults to `git config user.email`) and `JIRA_SITE` (defaults to `vanta.atlassian.net`).

If `JIRA_API_TOKEN` is unset, the step is skipped.

## Forking this repo

If you're adopting this as a starting point for your own dotfiles, change these before running `install.sh` — everything else is personal preference you can edit later without consequence.

### Must change

- **Git identity** in `git/.config/git/config`. Replace `name` and `email` with yours. If you skip this, every commit you make after stowing will be attributed to the wrong person. Use your provider's `noreply` email (e.g. `<id>+<username>@users.noreply.github.com`) if you don't want your real address in git history.
- **Clone URL** in the [Quick start](#quick-start) above — point it at your fork.

### Worth reviewing before you run

- **Claude Code settings** (`claude/.claude/settings.json`):
  - `model: opus` — Opus is expensive; consider `sonnet` or `haiku` if you're cost-conscious.
  - `skipDangerousModePermissionPrompt: true` — disables the confirmation prompt for dangerous-mode actions. Reasonable in ephemeral cloud devcontainers; a conscious trust tradeoff on a personal machine.
  - `enabledPlugins` — `pup` is Datadog-specific. Drop it (and the `datadog-pup` marketplace entry, and the `pup` binary install in `install.sh`) if you don't work at Datadog/Vanta-adjacent infra.
- **`gh` protocol** (`gh/.config/gh/config.yml`): set to `ssh`. Switch to `https` if you don't use SSH keys with GitHub.
- **Zsh theme** (`zsh/.zshrc`): `agnoster` requires a Powerline-patched font in your terminal. Pick a different `ZSH_THEME` if yours doesn't have one.

### EFS / Ona persistence

Entirely optional. If you don't use Ona or don't have a persistent mount, leave `EFS_MOUNT_POINT` unset and the script skips that step. Nothing else needs to change.

## Modifying and iterating

- **Edit a config:** edit the file in this repo (or edit the symlinked target — same thing) and commit.
- **Add a new package:** create a top-level directory mirroring `$HOME`, add it to the `PACKAGES` list in `install.sh`, and re-run `install.sh`.
- **Unstow everything:** `cd ~/dotfiles && stow -D -t ~ claude gh git nvim zellij zsh`. Symlinks go away; your `.bak` files remain where you left them.
- **Check what's linked:** `ls -la ~ | grep dotfiles` shows which files in `$HOME` point back here.

## Repo layout

```
.
├── install.sh              # bootstrap (Linux, idempotent)
├── claude/                 # Claude Code settings
├── gh/                     # GitHub CLI
├── git/                    # git identity + global ignore
├── nvim/                   # Neovim (lazy.nvim, LSP, treesitter)
├── zellij/                 # Zellij (terminal multiplexer)
└── zsh/                    # zsh + Oh My Zsh
```
