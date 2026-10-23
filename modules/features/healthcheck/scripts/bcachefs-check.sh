
#!/usr/bin/env bash
set -Eeuo pipefail

NTFY_URL=${NTFY_URL:-}
LOGFILE=${LOGFILE:-/var/log/health-check/bcachefs_check.log}

EXPECTED_UUID=${EXPECTED_UUID:-6efc72dc-a79e-4340-adf0-28ceb1be8769}
EXPECTED_DEVICES=${EXPECTED_DEVICES:-"hdd.hdd1 hdd.hdd2 sdd.sdd1"}

log() {
    printf '[%s] %s\n' "$(date --iso-8601=seconds)" "$*"
}

hostname_value() {
    local name=""
    if [[ -r /etc/hostname ]]; then
        IFS= read -r name </etc/hostname || true
    fi
    printf '%s' "${name:-unknown-host}"
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

    for command in curl findmnt bcachefs awk grep date; do
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
    notify "Test notification from bcachefs health check on $(hostname_value)"
    exit $?
fi

if [[ $EUID -ne 0 ]]; then
    echo "Must run as root" >&2
    exit 1
fi

mkdir -p "$(dirname "$LOGFILE")"
exec >>"$LOGFILE" 2>&1

failed=0

log "Starting Bcachefs health check"

if ! check_dependencies; then
    log "ERROR: Missing dependencies"
    notify "ERROR: Could not start Bcachefs check on $(hostname_value)" ||
        log "WARNING: Failed to send ntfy notification"
    exit 1
fi

mapfile -t mountpoints < <(findmnt -rn -t bcachefs -o TARGET)

if ((${#mountpoints[@]} == 0)); then
    log "ERROR: No mounted Bcachefs filesystems found"
    failed=1
fi

for mountpoint in "${mountpoints[@]}"; do
    log "Checking filesystem mounted at $mountpoint"

    if ! usage=$(bcachefs fs usage "$mountpoint" 2>&1); then
        log "ERROR: Bcachefs usage query failed for $mountpoint"
        log "$usage"
        failed=1
        continue
    fi

    printf '%s\n' "$usage"

    if ! grep -Fqx "Filesystem: $EXPECTED_UUID" <<<"$usage"; then
        log "ERROR: Unexpected filesystem UUID at $mountpoint"
        failed=1
        continue
    fi

    log "OK: Filesystem UUID matches at $mountpoint"

    if ! grep -Eq '^[[:space:]]*undegraded([[:space:]]|$)' <<<"$usage"; then
        log "ERROR: Filesystem is not reported as undegraded at $mountpoint"
        failed=1
    else
        log "OK: Filesystem reports undegraded at $mountpoint"
    fi

    for device in $EXPECTED_DEVICES; do
        if awk -v label="$device" '
            $1 == label && $2 == "(device" && $5 == "rw" {
                found = 1
            }
            END { exit !found }
        ' <<<"$usage"; then
            log "OK: Bcachefs member $device is present and rw"
        else
            log "ERROR: Bcachefs member $device is missing or not rw"
            failed=1
        fi
    done
done

if ((failed)); then
    log "ERROR: Bcachefs health check failed"
    notify "ERROR: Bcachefs health check failed on $(hostname_value)" ||
        log "WARNING: Failed to send ntfy notification"
    exit 1
fi

log "OK: Bcachefs health check passed"
exit 0
