#!/bin/bash
set -euo pipefail
# Disable inherited tracing before loading secrets.
set +x
DOTFILES="$(cd "$(dirname "$0")" && pwd)"
source "$DOTFILES/lib/common.sh"
export PATH="$HOME/.local/bin:$HOME/bin:$PATH"

[ "$(uname -s)" = Linux ] || { fail 'This installer supports Linux devcontainers only'; exit 1; }
if [ -r /etc/profile.d/ona-secrets.sh ]; then
    source /etc/profile.d/ona-secrets.sh
fi
case "$(uname -m)" in
    x86_64) ARCH=x86_64; ACLI_ARCH=amd64 ;;
    aarch64) ARCH=aarch64; ACLI_ARCH=arm64 ;;
    *) fail "Unsupported architecture: $(uname -m)"; exit 1 ;;
esac

# Establish the tools required by the bootstrap and installed configuration.
missing=()
for dep in git curl tar stow zsh jq python3; do
    command -v "$dep" >/dev/null || missing+=("$dep")
done
for dep in realpath; do
    command -v "$dep" >/dev/null || missing+=(coreutils)
done
if ! command -v mountpoint >/dev/null || ! command -v flock >/dev/null; then
    missing+=(util-linux)
fi
if ! /usr/bin/python3 -c "import tomlkit" 2>/dev/null; then
    missing+=(python3-tomlkit)
fi
if [ "${#missing[@]}" -gt 0 ]; then
    command -v apt-get >/dev/null || { fail "Install required dependencies: ${missing[*]}"; exit 1; }
    if [ "$(id -u)" = 0 ]; then
        apt-get update -qq
        DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${missing[@]}"
    else
        command -v sudo >/dev/null && sudo -n true || { fail 'Dependencies require passwordless sudo'; exit 1; }
        sudo -n apt-get update -qq
        sudo -n env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${missing[@]}"
    fi
fi

# Download into private staging; cleanup on normal exit, errors and signals.
umask 077
work_dir=$(mktemp -d)
trap 'rm -rf -- "$work_dir"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
mkdir -p "$HOME/.local/bin"

# A fresh install resolves latest releases; reruns never upgrade existing tools.
# Set ZELLIJ_VERSION or PUP_VERSION to a release tag to choose a version.
if ! command -v zellij >/dev/null; then
    zellij_release="${ZELLIJ_VERSION:+download/$ZELLIJ_VERSION}"
    zellij_release="${zellij_release:-latest/download}"
    curl -fSL --retry 3 --connect-timeout 15 --max-time 180 \
        -o "$work_dir/zellij.tar.gz" \
        "https://github.com/zellij-org/zellij/releases/$zellij_release/zellij-$ARCH-unknown-linux-musl.tar.gz"
    mkdir "$work_dir/zellij"
    tar xzf "$work_dir/zellij.tar.gz" -C "$work_dir/zellij"
    install -m 755 "$work_dir/zellij/zellij" "$HOME/.local/bin/zellij"
    ok 'Zellij installed'
else
    skip 'Zellij already installed'
fi

if ! command -v pup >/dev/null; then
    pup_release="${PUP_VERSION:+tags/$PUP_VERSION}"
    pup_release="${pup_release:-latest}"
    if pup_json=$(curl -fsSL --retry 3 --connect-timeout 15 --max-time 60 \
        "https://api.github.com/repos/datadog-labs/pup/releases/$pup_release") &&
        pup_url=$(printf '%s' "$pup_json" | jq -er --arg suffix "Linux_$ARCH.tar.gz" \
            '[.assets[] | select(.name | endswith($suffix)) | .browser_download_url][0] // empty'); then
        if curl -fSL --retry 3 --connect-timeout 15 --max-time 180 -o "$work_dir/pup.tar.gz" "$pup_url"; then
            mkdir "$work_dir/pup"
            if tar xzf "$work_dir/pup.tar.gz" -C "$work_dir/pup" && [ -f "$work_dir/pup/pup" ]; then
                install -m 755 "$work_dir/pup/pup" "$HOME/.local/bin/pup"
                ok 'pup installed'
            else
                skip 'pup archive invalid; rerun to retry'
            fi
        else
            skip 'pup download failed; rerun to retry'
        fi
    else
        skip 'pup release lookup failed; rerun to retry'
    fi
else
    skip 'pup already installed'
fi

# Unfold old Stow directories before applications can write runtime files.
python3 "$DOTFILES/lib/prepare-stow.py" "$DOTFILES" "$HOME" "${PACKAGES[@]}"
stow --no-folding --restow --dir "$DOTFILES" --target "$HOME" "${STOW_OPTIONS[@]}" "${PACKAGES[@]}"
ok 'Dotfiles linked'

# Merge portable Codex preferences; keep its writable state outside Stow.
/usr/bin/python3 "$DOTFILES/codex/install.py"

# gh stack (GitHub Stacked PRs) — gh extension for managing stacked branches/PRs.
# Extensions live in ~/.local/share/gh/extensions, so this is per-machine state
# rather than something stow can symlink from this repo.
if ! command -v gh &>/dev/null; then
    skip "gh stack: gh CLI not available (install GitHub CLI first)"
elif gh extension list 2>/dev/null | grep -q "gh-stack"; then
    skip "gh stack already installed"
else
    info "Installing gh stack..."
    # Needs an authed gh to resolve the release; don't fail the whole install if
    # this box hasn't run `gh auth login` yet.
    if gh extension install github/gh-stack; then
        ok "gh stack installed"
    else
        skip "gh stack: install failed (is gh authenticated? \`gh auth login\`)"
    fi
fi

# gh-stack agent skill — teaches Claude Code how to drive `gh stack`.
# Installed at user scope so it applies in every repo, not just this one.
# Existing folded directories are migrated before any skill installation.
if ! command -v gh &>/dev/null; then
    skip "gh-stack skill: gh CLI not available"
elif ! gh skill --help &>/dev/null; then
    # `gh skill` is a preview command; older gh releases don't have it.
    skip "gh-stack skill: this gh has no \`skill\` command (upgrade gh)"
elif gh skill list --agent claude-code --scope user --json skillName 2>/dev/null | grep -q '"gh-stack"'; then
    skip "gh-stack skill already installed"
else
    info "Installing gh-stack skill for Claude Code..."
    mkdir -p "$HOME/.claude"
    # --force so a re-run overwrites rather than blocking on an interactive
    # confirm; version resolves to the latest tagged gh-stack release.
    if gh skill install github/gh-stack gh-stack --agent claude-code --scope user --force; then
        ok "gh-stack skill installed"
    else
        skip "gh-stack skill: install failed (is gh authenticated? \`gh auth login\`)"
    fi
fi

# Oh My Zsh: download separately so a failed curl cannot look successful.
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    curl -fsSL --retry 3 --connect-timeout 15 --max-time 60 \
        -o "$work_dir/oh-my-zsh.sh" https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh
    KEEP_ZSHRC=yes RUNZSH=no CHSH=no sh "$work_dir/oh-my-zsh.sh" --unattended
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

# Prefer the installed zsh path; no password prompt during Ona startup.
zsh_path=$(command -v zsh)
if [ "$(getent passwd "$(id -un)" | cut -d: -f7)" != "$zsh_path" ]; then
    if [ "$(id -u)" = 0 ]; then
        chsh --shell "$zsh_path" "$(id -un)"
    elif command -v sudo >/dev/null && sudo -n chsh --shell "$zsh_path" "$(id -un)"; then
        ok 'Default shell set to zsh'
    else
        skip 'Could not change default shell non-interactively'
    fi
fi

# Install ACLI here; authenticate after persistence is ready in post-start.
if [ -n "${JIRA_API_TOKEN:-}" ] && ! command -v acli >/dev/null; then
    if curl -fSL --retry 3 --connect-timeout 15 --max-time 180 \
        -o "$work_dir/acli" "https://acli.atlassian.com/linux/latest/acli_linux_$ACLI_ARCH/acli"; then
        install -m 755 "$work_dir/acli" "$HOME/.local/bin/acli"
        ok 'ACLI installed'
    else
        skip 'ACLI download failed; rerun to retry'
    fi
fi
info 'Installation complete. Ona post-start handles persistence and Jira login.'
info 'Run ./doctor.sh to check this environment.'
