#!/usr/bin/env bash
set -euo pipefail

# postexec.sh - Called after a Samba session ends (user context)
# This script stops the session timer

STATE_DIR="@STATE_DIR@"
SHARE_NAME="@SHARE_NAME@"

# Get Samba environment variables
SMB_USER="${SMB_USER:-}"
SMB_PID="${SMB_PID:-$$}"
SMB_SHARE="${SMB_SHARE:-}"

if [[ -z "$SMB_USER" ]]; then
    logger -t "samba-timelock" -- "Error: SMB_USER not set in postexec"
    exit 1
fi

log() {
    logger -t "samba-timelock" -- "Postexec User $SMB_USER (PID $SMB_PID): $*"
}

# Source the lock-unlock script
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "${SCRIPT_DIR}/lock-unlock.sh"

log "Postexec hook called for share $SMB_SHARE"

# Stop the timer for this user
stop_timer "$SMB_USER"

# Optionally lock immediately or keep unlocked until expiry
# For now, we keep the session alive until the timer expires
log "Session ended for user $SMB_USER, timer stopped"

exit 0
