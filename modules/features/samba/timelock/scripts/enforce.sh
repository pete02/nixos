#!/usr/bin/env bash
set -euo pipefail

# enforce.sh - Periodic enforcement script (runs as root)
# Checks all users and locks sessions that have expired

STATE_DIR="@STATE_DIR@"
SHARE_NAME="@SHARE_NAME@"
MAX_SESSION_SECS="@MAX_SESSION_SECS@"
CUTOFF_HOUR="@CUTOFF_HOUR@"

log() {
    logger -t "samba-timelock" -- "Enforce: $*"
}

# Source the lock-unlock script
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "${SCRIPT_DIR}/lock-unlock.sh"

log "Running enforcement check"

# Find all state files
if [[ -d "$STATE_DIR" ]]; then
    for state_file in "${STATE_DIR}"/*.state; do
        [[ -f "$state_file" ]] || continue
        
        user=$(basename "$state_file" .state)
        
        if session_expired "$user"; then
            log "Session expired for user $user, locking"
            lock_share "$user"
            stop_timer "$user"
        fi
    done
fi

log "Enforcement check complete"

exit 0
