#!/usr/bin/env bash
set -euo pipefail

# postexec.sh - Called after a Samba session ends (user context)
# This script stops the session timer

STATE_DIR="@STATE_DIR@"


# Get Samba environment variables
SMB_USER="${SMB_USER:-}"
SMB_PID="${SMB_PID:-$$}"
SMB_SHARE="${SMB_SHARE:-}"

# Check that all required commands are available
check_commands() {
    local missing=0
    for cmd in date mkdir rm cat echo sleep logger lock-unlock; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo "Error: required command '$cmd' not found" >&2
            missing=1
        fi
    done
    return $missing
}

if [[ "${1:-}" == "--check" ]]; then
    if check_commands; then
        echo "All required commands are available"
        exit 0
    else
        exit 1
    fi
fi

if [[ -z "$SMB_USER" ]]; then
    logger -t "samba-timelock" -- "Error: SMB_USER not set in postexec"
    exit 1
fi

log() {
    logger -t "samba-timelock" -- "Postexec User $SMB_USER (PID $SMB_PID): $*"
}

log "Postexec hook called for share $SMB_SHARE"

# Stop the timer for this user
lock-unlock --state-dir="$STATE_DIR" stop-timer --user="$SMB_USER"

# Optionally lock immediately or keep unlocked until expiry
# For now, we keep the session alive until the timer expires
log "Session ended for user $SMB_USER, timer stopped"

exit 0
