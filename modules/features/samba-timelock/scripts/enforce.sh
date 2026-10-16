#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="@STATE_DIR@"
SESSION_FILE="${STATE_DIR}/session-start"
REVOKED_FILE="${STATE_DIR}/last-revoked"
SHARE_NAME="@SHARE_NAME@"
MAX_SESSION_SECS=@MAX_SESSION_SECS@
CUTOFF_HOUR=@CUTOFF_HOUR@

check() {
    echo "Checking date..."
    command -v date >/dev/null || return 1

    echo "Checking cat..."
    command -v cat >/dev/null || return 1

    echo "Checking logger..."
    command -v logger >/dev/null || return 1

    echo "Checking smbcontrol..."
    command -v smbcontrol >/dev/null || return 1

    echo "Checking rm..."
    command -v rm >/dev/null || return 1

    echo "Checking raysha-filter..."
    command -v raysha-filter >/dev/null || return 1

    echo "Checking alanna-filter..."
    command -v raysha-filter >/dev/null || return 1
}

if [[ "${1:-}" == "--check" ]]; then
    check
    exit $?
fi

[[ -f "${SESSION_FILE}" ]] || exit 0
start=$(cat "${SESSION_FILE}")
now=$(date +%s)
hour=$(date +%-H)
elapsed=$(( now - start ))

if [[ "$elapsed" -ge "${MAX_SESSION_SECS}" ]] || [[ "$hour" -ge "${CUTOFF_HOUR}" ]]; then
    logger -t samba-timelock "LIMIT REACHED: force-closing share"
    smbcontrol smbd close-share "${SHARE_NAME}" || true
    date +%s > "${REVOKED_FILE}"
    rm -f "${SESSION_FILE}"
    raysha-filter on
    alanna-filter on
fi
