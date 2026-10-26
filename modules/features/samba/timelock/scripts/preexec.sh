#!/usr/bin/env bash
set -euo pipefail

# preexec.sh - Samba connection authorization through generic timelock.


check_commands() {
    local missing=0

    for cmd in date mkdir chmod mv flock logger timelock-samba; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo "Missing required command: $cmd" >&2
            missing=1
        fi
    done

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


if ! check_commands; then
    logger -t samba-timelock -- \
        "Authorization failed: required command missing" || true
    exit 1
fi

exec "@TIMELOCK@" unlock
