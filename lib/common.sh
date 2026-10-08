#!/bin/bash
# Shared by install.sh, post-start-install.sh and doctor.sh.
PACKAGES=(claude gh git zsh zellij)
PERSIST_PATHS=(.claude.json .claude/.credentials.json .config/gh/hosts.yml .config/acli .aws .zsh_history .codex/auth.json)

info() { printf '[info] %s\n' "$*"; }
skip() { printf '[skip] %s\n' "$*"; }
ok() { printf '[ ok ] %s\n' "$*"; }
fail() { printf '[error] %s\n' "$*" >&2; return 1; }

# Never overwrite an earlier backup, including dangling symlinks.
backup_path() {
    local src="$1" dst="$1.bak" number=0
    while [ -e "$dst" ] || [ -L "$dst" ]; do
        number=$((number + 1))
        dst="$src.bak.$number"
    done
    mv -- "$src" "$dst"
    info "Preserved $src as $dst"
}

# Resolve both paths before comparing them. Do not create the mount directory.
validate_efs() {
    local home_dir
    EFS_DIR=$(realpath -m -- "${EFS_MOUNT_POINT:?}") || return 1
    home_dir=$(realpath -m -- "${1:-$HOME}") || return 1
    case "$EFS_MOUNT_POINT" in /*) ;; *) fail 'EFS_MOUNT_POINT must be absolute'; return 1 ;; esac
    case "$EFS_DIR/" in "$home_dir/"*) fail 'EFS must be outside HOME'; return 1 ;; esac
    case "$home_dir/" in "$EFS_DIR/"*) fail 'EFS must not contain HOME'; return 1 ;; esac
    [ "$EFS_DIR" != / ] || { fail 'EFS must not be /'; return 1; }
    mountpoint -q -- "$EFS_DIR" || { fail 'EFS is not mounted; local files left untouched'; return 1; }
    [ -w "$EFS_DIR" ] || { fail 'EFS is not writable'; return 1; }
}

# Caller has verified the mount. Preserve conflicting files on both sides.
link_to_efs() {
    local name="$1" home_dir src dst="$EFS_DIR/$1" parent resolved
    home_dir=$(realpath -m -- "${2:-$HOME}")
    src="$home_dir/$name"
    parent=$(dirname "$src")
    resolved=$(realpath -m -- "$parent")
    case "$resolved/" in "$home_dir/"*) ;; *) fail "Refusing redirected parent for $name; run install.sh first"; return 1 ;; esac
    # Reject persistent symlinks/parents escaping the verified mount.
    resolved=$(realpath -m -- "$dst")
    case "$resolved/" in "$EFS_DIR/"*) ;; *) fail "Persistent path escapes EFS: $name"; return 1 ;; esac
    if [ -L "$src" ] && [ "$(readlink "$src")" = "$dst" ]; then
        return 0
    fi
    mkdir -p -- "$parent" "$(dirname "$dst")"
    if [ ! -e "$dst" ] && [ ! -L "$dst" ] && [ -e "$src" ] && [ ! -L "$src" ]; then
        # Copy first, then preserve the original locally. Interrupted copies never
        # replace the destination and the source is not removed before success.
        local stage
        stage=$(mktemp -d "$EFS_DIR/.dotfiles-migrate.XXXXXX")
        if ! cp -a -- "$src" "$stage/value"; then
            rm -rf -- "$stage"
            fail "Could not persist $name; local file left untouched"
            return 1
        fi
        mv -n -- "$stage/value" "$dst"
        rm -rf -- "$stage"
    fi
    if [ -e "$src" ] || [ -L "$src" ]; then
        backup_path "$src"
    fi
    ln -s -- "$dst" "$src"
}

# Runtime state must never become a Stow source, even in an old checkout.
STOW_OPTIONS=('--ignore=(^|/)(hosts\.yml|\.credentials\.json|settings\.local\.json|skills|projects|sessions|debug|cache|todos)(/|$)')

# Isolated traps guarantee token cleanup without replacing caller traps.
authenticate_jira() (
    set +x
    umask 077
if [ -z "${JIRA_API_TOKEN:-}" ]; then
    skip 'JIRA_API_TOKEN unset; skipping Jira login'
elif [ -z "${JIRA_EMAIL:-}" ] || [[ "$JIRA_EMAIL" == *@users.noreply.github.com ]]; then
    fail 'Set JIRA_EMAIL to your Atlassian account email (not your Git commit email)'
    exit 1
elif ! command -v acli >/dev/null; then
    fail 'ACLI unavailable; rerun install.sh with JIRA_API_TOKEN set'
    exit 1
elif acli jira auth status >/dev/null 2>&1; then
    skip 'ACLI already authenticated'
else
    token_file=$(mktemp)
    trap 'rm -f -- "$token_file"' EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    printf '%s' "$JIRA_API_TOKEN" > "$token_file"
    if acli jira auth login --site "${JIRA_SITE:-vanta.atlassian.net}" \
        --email "$JIRA_EMAIL" --token < "$token_file" >/dev/null 2>&1; then
        ok 'ACLI authenticated'
    else
        fail 'Jira login failed; check JIRA_EMAIL, JIRA_SITE and JIRA_API_TOKEN'
        exit 1
    fi
fi

)
