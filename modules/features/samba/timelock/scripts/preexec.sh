#!/usr/bin/env bash
set -euo pipefail

# preexec.sh - Samba connection authorization through generic timelock.

STATE_DIR="@STATE_DIR@"
MAX_SESSION_SECS="@MAX_SESSION_SECS@"
COOLDOWN_SECS="@COOLDOWN_SECS@"
CUTOFF_HOUR="@CUTOFF_HOUR@"
NOOP_COMMAND="@NOOP_COMMAND@"

check_commands() {
    local missing=0

    for cmd in date mkdir chmod mv flock logger timelock; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo "Missing required command: $cmd" >&2
            missing=1
        fi
    done

    if [[ ! -x "$NOOP_COMMAND" ]]; then
        echo "Missing executable: $NOOP_COMMAND" >&2
        missing=1
    fi

    return "$missing"
}

if [[ "${1:-}" == "--check" ]]; then
    check_commands
    exit $?
fi

if [[ $# -ne 0 ]]; then
    echo "Usage: preexec [--check]" >&2
    exit 2
fi

export TIMELOCK_STATE_DIR="$STATE_DIR"
export TIMELOCK_MAX_SESSION_SECS="$MAX_SESSION_SECS"
export TIMELOCK_COOLDOWN_SECS="$COOLDOWN_SECS"
export TIMELOCK_CUTOFF_HOUR="$CUTOFF_HOUR"
export TIMELOCK_LOCK_COMMAND="$NOOP_COMMAND"
export TIMELOCK_UNLOCK_COMMAND="$NOOP_COMMAND"

if ! check_commands; then
    logger -t samba-timelock -- \
        "Authorization failed: required command missing" || true
    exit 1
fi

exec timelock samba check
