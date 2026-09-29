#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="@STATE_DIR@"
SESSION_FILE="${STATE_DIR}/session-start"
REVOKED_FILE="${STATE_DIR}/last-revoked"
SHARE_NAME="@SHARE_NAME@"

check() {
    echo "Checking date..."
    command -v date >/dev/null || return 1

    echo "Checking rm..."
    command -v rm >/dev/null || return 1

    echo "Checking logger..."
    command -v logger >/dev/null || return 1

    echo "Checking smbstatus..."
    command -v smbstatus >/dev/null || return 1

    echo "Checking raysha-filter..."
    command -v raysha-filter >/dev/null || return 1

    echo "Checking alanna-filter..."
    command -v alanna-filter >/dev/null || return 1
}

if [[ "${1:-}" == "--check" ]]; then
    check
    exit $?
fi

# Only finalize once every connection to the share is actually gone
remaining=$(smbstatus -S 2>/dev/null | awk -v s="${SHARE_NAME}" '$1==s' | wc -l)
if [[ "$remaining" -eq 0 ]]; then
    date +%s > "${REVOKED_FILE}"
    rm -f "${SESSION_FILE}"
    raysha-filter on
    alanna-filter on
    logger -t samba-timelock "ACCESS ENDED: 72h cooldown started"
fi
