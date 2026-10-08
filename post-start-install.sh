#!/bin/bash
set -euo pipefail
set +x
DOTFILES="$(cd "$(dirname "$0")" && pwd)"
source "$DOTFILES/lib/common.sh"
export PATH="$HOME/.local/bin:$HOME/bin:$PATH"
umask 077

[ "$(uname -s)" = Linux ] || { fail 'Post-start requires Linux'; exit 1; }
# Ona installs this file outside interactive shell startup too.
if [ -r /etc/profile.d/ona-secrets.sh ]; then
    source /etc/profile.d/ona-secrets.sh
fi

if [ -n "${EFS_MOUNT_POINT:-}" ]; then
    validate_efs
    # Serialize migrations across environments sharing this EFS directory.
    exec 9>"$EFS_DIR/.dotfiles.lock"
    flock -x 9
    for name in "${PERSIST_PATHS[@]}"; do
        link_to_efs "$name"
    done
    flock -u 9
    exec 9>&-
    ok 'EFS persistence configured'
else
    skip 'EFS_MOUNT_POINT unset; keeping state local'
fi

authenticate_jira
