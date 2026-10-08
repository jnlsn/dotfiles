#!/bin/bash
# Read-only diagnostics: no login attempts, token output or filesystem repairs.
set -uo pipefail
set +x
DOTFILES="$(cd "$(dirname "$0")" && pwd)"
source "$DOTFILES/lib/common.sh"
export PATH="$HOME/.local/bin:$HOME/bin:$PATH"
issues=0
warn() { printf '[warn] %s\n' "$*"; issues=$((issues + 1)); }

if [ "$(uname -s)" != Linux ]; then
    warn 'This configuration targets Linux devcontainers'
fi
for tool in git curl tar stow zsh jq python3 realpath mountpoint flock zellij gh claude codex pup; do
    if command -v "$tool" >/dev/null; then
        ok "$tool available"
    else
        warn "$tool missing"
    fi
done
if command -v gh >/dev/null; then
    if gh auth status >/dev/null 2>&1; then ok 'GitHub authentication'; else warn 'GitHub authentication unavailable'; fi
fi
if command -v acli >/dev/null; then
    if acli jira auth status >/dev/null 2>&1; then ok 'Jira authentication'; else warn 'Jira authentication unavailable'; fi
elif [ -n "${JIRA_API_TOKEN:-}" ]; then
    warn 'Jira token configured but ACLI missing'
else
    skip 'ACLI not configured'
fi
if [ -n "${JIRA_API_TOKEN:-}" ] && { [ -z "${JIRA_EMAIL:-}" ] || [[ "$JIRA_EMAIL" == *@users.noreply.github.com ]]; }; then
    warn 'Set JIRA_EMAIL to your Atlassian account email'
fi

if command -v python3 >/dev/null && command -v git >/dev/null; then
    if python3 - "$DOTFILES" "$HOME" "${PACKAGES[@]}" <<'PY'
from pathlib import Path
import subprocess
import sys
repo, home = (Path(p).resolve() for p in sys.argv[1:3])
packages = sys.argv[3:]
issues = []
files = subprocess.check_output(['git', '-C', str(repo), 'ls-files', '-z']).decode().split('\0')
for name in files:
    if not name or name.split('/')[0] not in packages or not (repo / name).is_file():
        continue
    src = repo / name
    target = home.joinpath(*Path(name).parts[1:])
    if not target.is_symlink() or target.resolve() != src.resolve():
        issues.append(f'Link missing or incorrect: {target}')
    for parent in target.parents:
        if parent == home:
            break
        if parent.is_symlink():
            issues.append(f'Directory is folded/redirected: {parent}; run install.sh')
for issue in sorted(set(issues)):
    print('[warn]', issue)
sys.exit(bool(issues))
PY
    then ok 'Stow links'; else warn 'Stow configuration needs attention'; fi
fi

if /usr/bin/python3 -c 'import tomlkit' 2>/dev/null; then
    if /usr/bin/python3 "$DOTFILES/codex/install.py" --check; then
        ok 'Codex preferences'
    else
        warn 'Codex preferences need attention; rerun install.sh'
    fi
else
    warn 'python3-tomlkit missing; cannot check Codex preferences'
fi

if [ -n "${EFS_MOUNT_POINT:-}" ]; then
    if command -v realpath >/dev/null && command -v mountpoint >/dev/null && validate_efs; then
        ok 'EFS mount'
        for name in "${PERSIST_PATHS[@]}"; do
            path="$HOME/$name"
            if [ ! -L "$path" ] || [ "$(readlink "$path")" != "$EFS_DIR/$name" ]; then
                warn "Persistence link missing or incorrect: $name"
            elif [ ! -e "$path" ]; then
                # New accounts may not have created their credential file yet.
                warn "Persistence target absent: $name (possibly not initialized yet)"
            else
                ok "Persistence: $name"
            fi
        done
    else
        warn 'EFS unavailable or unsafe; run post-start after mounting'
    fi
else
    skip 'EFS not configured'
fi
if [ "$issues" -gt 0 ]; then
    printf '%s check(s) need attention.\n' "$issues"
    exit 1
fi
ok 'Environment checks passed'
