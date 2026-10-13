#!/usr/bin/env bash
set -Eeuo pipefail

NTFY_URL=${NTFY_URL:-https://ntfy.lumilukko.com/Server}
LOGFILE=${LOGFILE:-/var/log/health-check/bcachefs_check.log}
EXPECT=${EXPECT:-}

log() {
    printf '[%s] %s\n' "$(date --iso-8601=seconds)" "$*"
}

notify() {
    local message=$1
    curl --fail --silent --show-error \
        --max-time 10 \
        -H "Title: bcachefs health check" \
        -d "$message" \
        "$NTFY_URL"
}

check_dependencies() {
    local missing=0

    for command in curl findmnt blkid bcachefs; do
        if ! command -v "$command" >/dev/null 2>&1; then
            printf 'Missing dependency: %s\n' "$command" >&2
            missing=1
        fi
    done

    return "$missing"
}

if [[ ${1:-} == "--check" ]]; then
    check_dependencies
    exit $?
fi

if [[ ${1:-} == "--test-notify" ]]; then
    notify "Test notification from bcachefs health check"
    exit $?
fi

if [[ $EUID -ne 0 ]]; then
    echo "Must run as root" >&2
    exit 1
fi

mkdir -p "$(dirname "$LOGFILE")"
exec >>"$LOGFILE" 2>&1

failed=0

log "Starting bcachefs health check"

if ! check_dependencies; then
    notify "could not start bcachefs check"
    log "ERROR: Missing dependencies"
    exit 1
fi

# Ensure at least one bcachefs filesystem is mounted.
mapfile -t mountpoints < <(findmnt -rn -t bcachefs -o TARGET)

if ((${#mountpoints[@]} == 0)); then
    log "ERROR: No mounted bcachefs filesystems found"
    failed=1
fi

# Ensure every configured device exists and contains bcachefs data.
for device in $EXPECT; do
    path="/dev/$device"

    if [[ ! -b "$path" ]]; then
        log "ERROR: Expected device $path does not exist"
        failed=1
        continue
    fi

    fstype=$(blkid -s TYPE -o value "$path" 2>/dev/null || true)
    if [[ "$fstype" != "bcachefs" ]]; then
        log "ERROR: $path has filesystem type '${fstype:-unknown}', expected bcachefs"
        failed=1
    else
        log "OK: $path is a bcachefs device"
    fi
done

# Query usage for each mounted filesystem. This checks that bcachefs
# can report its current filesystem and per-device usage.
for mountpoint in "${mountpoints[@]}"; do
    log "Checking filesystem mounted at $mountpoint"

    if bcachefs fs usage "$mountpoint"; then
        log "OK: bcachefs usage query succeeded for $mountpoint"
    else
        log "ERROR: bcachefs usage query failed for $mountpoint"
        failed=1
    fi
done

if ((failed)); then
    log "ERROR: bcachefs health check failed"
    notify "ERROR: bcachefs health check failed on $(hostname)" || \
        log "WARNING: Failed to send ntfy notification"
    exit 1
fi

log "OK: bcachefs health check passed"
exit 0
