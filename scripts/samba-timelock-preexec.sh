#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="@STATE_DIR@"
SESSION_FILE="${STATE_DIR}/session-start"
REVOKED_FILE="${STATE_DIR}/last-revoked"
COOLDOWN_SECS=@COOLDOWN_SECS@
CUTOFF_HOUR=@CUTOFF_HOUR@

check() {
    echo "Checking logger..."
    command -v logger >/dev/null || return 1

    echo "Checking date..."
    command -v date >/dev/null || return 1

    echo "Checking cat..."
    command -v cat >/dev/null || return 1

    echo "Checking echo..."
    command -v echo >/dev/null || return 1

    echo "Checking raysha-filter..."
    command -v raysha-filter >/dev/null || return 1


    echo "Checking alanna-filter..."
    command -v raysha-filter >/dev/null || return 1
}

if [[ "${1:-}" == "--check" ]]; then
    check
    exit $?
fi

now=$(date +%s)
hour=$(date +%-H)   # %-H, not %H: avoids "08"/"09" being read as octal

if [[ -f "${REVOKED_FILE}" ]]; then
    last=$(cat "${REVOKED_FILE}")
    elapsed=$(( now - last ))
    if [[ "$elapsed" -lt "${COOLDOWN_SECS}" ]]; then
        logger -t samba-timelock "DENY connect: cooldown active ($(( (COOLDOWN_SECS - elapsed) / 3600 ))h left)"
        exit 1
    fi
fi

if [[ "$hour" -ge "${CUTOFF_HOUR}" ]]; then
    logger -t samba-timelock "DENY connect: past cutoff (${CUTOFF_HOUR}:00)"
    exit 1
fi

if [[ ! -f "${SESSION_FILE}" ]]; then
    echo "$now" > "${SESSION_FILE}"
    logger -t samba-timelock "ACCESS GRANTED: session started"
    raysha-filter off
    alanna-filter off
fi
exit 0
