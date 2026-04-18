#!/bin/bash
# shellcheck source-path=SCRIPTDIR
# Session data — parses Claude Code JSON input and derives session-level values
# Requires: $input (raw JSON string) set before sourcing
# Sources: lib/core.sh
# shellcheck disable=SC2034,SC1091  # SC2034: vars exported to sourcing scripts, SC1091: source paths resolved at runtime

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=core.sh
source "$LIB_DIR/core.sh"

# MARK: - Raw JSON Fields

# shellcheck disable=SC2154  # $input is set by the sourcing script
MODEL=$(echo "$input" | jq -r '.model.display_name // "Unknown"' | sed 's/ context)/)/g')
FULL_DIR=$(echo "$input" | jq -r '.workspace.current_dir // "."')
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
CONTEXT_SIZE=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
USED_PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0')
WORKTREE_NAME=$(echo "$input" | jq -r '.worktree.name // empty')
SESSION_NAME=$(echo "$input" | jq -r '.session_name // empty')

# MARK: - Derived Values

# Git root
GIT_ROOT=$(git -C "$FULL_DIR" rev-parse --show-toplevel 2>/dev/null)

# Directory — relative to git root (shell substitution works on BSD + GNU; GNU
# realpath's --relative-to is unavailable on macOS).
if [ -n "$GIT_ROOT" ]; then
    if [ "$FULL_DIR" = "$GIT_ROOT" ]; then
        DIR="~"
    else
        DIR="${FULL_DIR#$GIT_ROOT/}"
    fi
else
    DIR="$FULL_DIR"
fi

# Environment friendly name and URL (codespace or ONA)
FRIENDLY_NAME=""
ENV_URL=""
if [ -n "$CODESPACE_NAME" ]; then
    FRIENDLY_NAME=$(echo "$CODESPACE_NAME" | grep -oE '^[^-]+-[^-]+' || echo "$CODESPACE_NAME")
    ENV_URL="https://github.com/VantaInc/obsidian/codespaces"
elif [ "$IS_ON_ONA" = "true" ]; then
    # ona CLI only sees the current environment even when multiple are running
    ONA_JSON=$(get_cached "ona-env-info-$(basename "$GIT_ROOT")" 300 ona environment list -r -o json)
    if [ -n "$ONA_JSON" ]; then
        ONA_NAME=$(echo "$ONA_JSON" | jq -r '.[0].metadata.name // empty')
        ONA_ID=$(echo "$ONA_JSON" | jq -r '.[0].id // empty')
        ONA_BRANCH=$(echo "$ONA_JSON" | jq -r '.[0].spec.content.initializer.specs[0].git.cloneTarget // empty')
        if [ -n "$ONA_ID" ]; then
            ONA_BASE_URL="${GITPOD_API_URL%/api}"
            ENV_URL="${ONA_BASE_URL:-https://app.gitpod.io}/details/${ONA_ID}"
        fi
        SHORT_ID=""
        [ -n "$ONA_ID" ] && SHORT_ID=$(printf '%s' "${ONA_ID##*-}" | cut -c1-7)
        if [ -n "$ONA_NAME" ]; then
            FRIENDLY_NAME="${ONA_NAME}${SHORT_ID:+ $SHORT_ID}"
        elif [ -n "$ONA_BRANCH" ]; then
            FRIENDLY_NAME="${ONA_BRANCH}${SHORT_ID:+ $SHORT_ID}"
        else
            FRIENDLY_NAME="ONA ${HOSTNAME:-unknown}"
        fi
    else
        FRIENDLY_NAME="ONA ${HOSTNAME:-unknown}"
    fi
fi

# Context usage — integer percentage + display values
USED_PCT_INT=0
USED_K=0
LIMIT_DISPLAY=""
COMPACT_PCT=0
WARN_PCT=0
CTX_COLOR=""

if [ "$USED_PCT" != "0" ] && [ "$USED_PCT" != "null" ] && [ "${CONTEXT_SIZE:-0}" -gt 0 ]; then
    USED_PCT_INT=${USED_PCT%.*}  # truncate decimal
    [ -z "$USED_PCT_INT" ] && USED_PCT_INT=0
    USED_K=$(( CONTEXT_SIZE * USED_PCT_INT / 100 / 1000 ))

    # Format limit: 1M for >=1000000, else NK
    if (( CONTEXT_SIZE >= 1000000 )); then
        LIMIT_DISPLAY="1M"
    else
        LIMIT_DISPLAY="$((CONTEXT_SIZE / 1000))K"
    fi

    # Autocompact buffer is fixed at 33k tokens — compute dynamic thresholds
    AUTOCOMPACT_BUFFER=33000
    COMPACT_PCT=$(( (CONTEXT_SIZE - AUTOCOMPACT_BUFFER) * 100 / CONTEXT_SIZE ))
    WARN_PCT=$(( COMPACT_PCT - 10 ))

    # Color by threshold
    if (( USED_PCT_INT >= COMPACT_PCT )); then
        CTX_COLOR="\033[1;31m"  # Bold red
    elif (( USED_PCT_INT >= WARN_PCT )); then
        CTX_COLOR="\033[1;33m"  # Bold yellow
    elif (( USED_PCT_INT >= 50 )); then
        CTX_COLOR="\033[33m"    # Yellow
    else
        CTX_COLOR="\033[32m"    # Green
    fi
fi
