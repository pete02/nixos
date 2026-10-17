#!/usr/bin/env bash
set -euo pipefail

# preexec.sh - Called before a Samba session starts (user context)
# This script unlocks the share and starts the session timer

STATE_DIR="@STATE_DIR@"
COOLDOWN_SECS="@COOLDOWN_SECS@"
CUTOFF_HOUR="@CUTOFF_HOUR@"

# Get Samba environment variables
SMB_USER="${SMB_USER:-}"
SMB_PID="${SMB_PID:-$$}"
SMB_SHARE="${SMB_SHARE:-}"

if [[ -z "$SMB_USER" ]]; then
    logger -t "samba-timelock" -- "Error: SMB_USER not set in preexec"
    exit 1
fi

log() {
    logger -t "samba-timelock" -- "Preexec User $SMB_USER (PID $SMB_PID): $*"
}

# Source the lock-unlock script
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "${SCRIPT_DIR}/lock-unlock.sh"

log "Preexec hook called for share $SMB_SHARE"

# Check if user is already unlocked
if is_unlocked "$SMB_USER"; then
    local current_time
    current_time=$(date +%s)
    local unlock_time
    unlock_time=$(get_unlock_time "$SMB_USER")
    local elapsed=$((current_time - unlock_time))
    
    if [[ "$elapsed" -lt "$COOLDOWN_SECS" ]]; then
        local remaining=$((COOLDOWN_SECS - elapsed))
        log "User $SMB_USER already unlocked, cooldown active (${remaining}s remaining)"
        exit 0
    fi
    
    log "User $SMB_USER cooldown expired, re-locking"
    lock_share "$SMB_USER"
    stop_timer "$SMB_USER"
fi

# Unlock the share
unlock_share "$SMB_USER"
log "Share unlocked for user $SMB_USER"

exit 0
