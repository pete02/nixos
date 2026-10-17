#!/usr/bin/env bash
set -euo pipefail

# enforce.sh - Periodic enforcement script (runs as root)
# Checks all users and locks sessions that have expired

STATE_DIR="@STATE_DIR@"

MAX_SESSION_SECS="@MAX_SESSION_SECS@"
CUTOFF_HOUR="@CUTOFF_HOUR@"

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

log() {
    logger -t "samba-timelock" -- "Enforce: $*"
}

log "Running enforcement check"

# Find all state files
if [[ -d "$STATE_DIR" ]]; then
    for state_file in "${STATE_DIR}"/*.state; do
        [[ -f "$state_file" ]] || continue
        
        user=$(basename "$state_file" .state)
        
        # Check if session expired using lock-unlock
        if ! lock-unlock --state-dir="$STATE_DIR" --max-session-secs="$MAX_SESSION_SECS" --cutoff-hour="$CUTOFF_HOUR" check --user="$user"; then
            log "Session expired for user $user, locking"
            lock-unlock --state-dir="$STATE_DIR" lock --user="$user"
        fi
    done
fi

log "Enforcement check complete"

exit 0
