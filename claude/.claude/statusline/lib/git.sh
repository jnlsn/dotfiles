#!/bin/bash
# Git state extraction — single `git status` call, exports all variables
# Requires: GIT_ROOT and FULL_DIR set before sourcing
# shellcheck disable=SC2034  # Variables are exported to sourcing scripts

BRANCH=""
DIRTY=""
AHEAD=""
BEHIND=""
HAS_UPSTREAM=false
STAGED_COUNT=0
PENDING_COUNT=0
UNTRACKED_COUNT=0

if [ -n "$GIT_ROOT" ]; then
    GIT_STATUS=$(git -C "$FULL_DIR" --no-optional-locks status -b --porcelain=v2 2>/dev/null)

    # Parse branch name
    BRANCH=$(echo "$GIT_STATUS" | grep '^# branch.head ' | cut -d' ' -f3)

    # Parse upstream
    UPSTREAM=$(echo "$GIT_STATUS" | grep '^# branch.upstream ' | cut -d' ' -f3)
    [ -n "$UPSTREAM" ] && HAS_UPSTREAM=true

    # Parse ahead/behind from "# branch.ab +N -M"
    AB_LINE=$(echo "$GIT_STATUS" | grep '^# branch.ab ')
    if [ -n "$AB_LINE" ]; then
        AB_PLUS=$(echo "$AB_LINE" | awk '{print $3}')  # "+N"
        AB_MINUS=$(echo "$AB_LINE" | awk '{print $4}')  # "-M"
        AHEAD="${AB_PLUS#+}"   # strip leading +
        BEHIND="${AB_MINUS#-}" # strip leading -
    fi

    # Parse file statuses
    while IFS= read -r line; do
        case "$line" in
            "? "*)
                UNTRACKED_COUNT=$((UNTRACKED_COUNT + 1))
                ;;
            "1 "* | "2 "*)
                # XY is chars 2-3 (0-indexed) after "1 " or "2 "
                local_xy="${line:2:2}"
                idx_char="${local_xy:0:1}"
                wt_char="${local_xy:1:1}"
                [ "$idx_char" != "." ] && STAGED_COUNT=$((STAGED_COUNT + 1))
                [ "$wt_char" != "." ] && PENDING_COUNT=$((PENDING_COUNT + 1))
                ;;
        esac
    done <<< "$GIT_STATUS"

    # Dirty indicator
    TOTAL_DIRTY=$((STAGED_COUNT + PENDING_COUNT + UNTRACKED_COUNT))
    [ "$TOTAL_DIRTY" -gt 0 ] && DIRTY="*"
fi

# Diff stats (insertions/deletions vs HEAD)
DIFF_ADD=0
DIFF_DEL=0
if [ -n "$BRANCH" ] && [ -n "$DIRTY" ]; then
    DIFF_STAT=$(git -C "$FULL_DIR" --no-optional-locks diff HEAD --shortstat 2>/dev/null)
    # sed instead of grep -oP: PCRE lookahead unavailable in BSD grep on macOS.
    DIFF_ADD=$(echo "$DIFF_STAT" | sed -nE 's/.*[[:space:]]([0-9]+) insertion.*/\1/p')
    DIFF_DEL=$(echo "$DIFF_STAT" | sed -nE 's/.*[[:space:]]([0-9]+) deletion.*/\1/p')
    [ -z "$DIFF_ADD" ] && DIFF_ADD=0
    [ -z "$DIFF_DEL" ] && DIFF_DEL=0
fi

# Sanitized branch + repo ID for cache keys (slashes in branch names break file paths)
SAFE_BRANCH="${BRANCH//\//_}"
REPO_ID=$(printf '%s' "$GIT_ROOT" | md5sum | cut -c1-8)
