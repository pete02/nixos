#!/usr/bin/env bash
set -euo pipefail

SUCCESS_URL="@NTFY_SUCCESS_URL@"
FAILURE_URL="@NTFY_FAILURE_URL@"
REPO_URL="@REPO_URL@"

STATE_DIR="/var/lib/gitops"
REPO="$STATE_DIR/repo"
BRANCH="stable"
TIMESTAMP_FILE="$STATE_DIR/last-sync"
REV_FILE="$STATE_DIR/last-deployed-rev"
LOG_FILE="$STATE_DIR/gitops.log"
MAX_LOG_BYTES=$((5 * 1024 * 1024))
RUN_START_OFFSET=0
STEP="initialization"

# Timestamped message to both stdout (journal) and the log file.
log() {
    printf '%s [%s] %s\n' "$(date -Iseconds)" "$$" "$*" | tee -a "$LOG_FILE"
}

# Run a command, logging the command line and all of its stdout/stderr.
# Returns the command's own exit code (not tee's).
run() {
    local rc=0
    log "+ $*"
    "$@" 2>&1 | tee -a "$LOG_FILE" || rc=${PIPESTATUS[0]}
    return "$rc"
}

notify() {
    local url="$1"
    local message="$2"
    local priority="${3:-default}"

    curl --silent --show-error --fail \
        --connect-timeout 5 \
        --max-time 10 \
        -H "Title: gitops" \
        -H "Priority: $priority" \
        -d "$message" \
        "$url" || log "WARNING: Failed to send ntfy notification"
}

on_exit() {
    local rc=$?

    if (( rc != 0 )); then
        log "FAILED during: ${STEP} (exit code: ${rc})"

        # Only this run's output, last 20 lines, capped in size for ntfy.
        local tail_out=""
        tail_out="$(tail -c +$((RUN_START_OFFSET + 1)) "$LOG_FILE" 2>/dev/null \
            | tail -n 20 | tail -c 1500 || true)"

        notify "$FAILURE_URL" \
            "Update failed on ${HOSTNAME:-unknown} during: ${STEP} (exit code: ${rc})
${tail_out}" \
            high
    else
        log "Run finished OK"
    fi
}

check() {
    local cmd
    for cmd in curl git ssh nixos-rebuild systemd-run systemctl readlink tee tail stat; do
        echo "Checking ${cmd}..."
        command -v "$cmd" >/dev/null || return 1
    done
}

if [[ "${1:-}" == "--check" ]]; then
    check
    exit $?
fi

STEP="preparation"
mkdir -p "$STATE_DIR"

# Simple rotation: keep one old log.
if [[ -f "$LOG_FILE" ]] && (( $(stat -c %s "$LOG_FILE") > MAX_LOG_BYTES )); then
    mv -f "$LOG_FILE" "${LOG_FILE}.1"
fi
touch "$LOG_FILE"
RUN_START_OFFSET="$(stat -c %s "$LOG_FILE")"

trap on_exit EXIT
log "=== gitops run started on ${HOSTNAME:-unknown} ==="

if [[ ! -d "$REPO/.git" ]]; then
    STEP="initial clone"
    log "No local clone found, cloning ${REPO_URL}..."
    run git clone --branch "$BRANCH" "$REPO_URL" "$REPO"
fi

cd "$REPO"

STEP="fetch"
run git fetch origin "$BRANCH"

STEP="revision check"
REMOTE="$(git rev-parse "origin/${BRANCH}")"
DEPLOYED="$(cat "$REV_FILE" 2>/dev/null || true)"

DEPLOYED_NOW=0

if [[ "$REMOTE" != "$DEPLOYED" ]]; then
    log "Remote has updates (${DEPLOYED:-none} -> ${REMOTE}), triggering autoupdater"

    STEP="reset"
    run git reset --hard "origin/${BRANCH}"

    STEP="NixOS rebuild"
    run nixos-rebuild switch --flake "${REPO}#${HOSTNAME:?HOSTNAME is required}"

    # Only record the revision after a successful switch, so failures retry.
    echo "$REMOTE" > "$REV_FILE"
    date -Iseconds > "$TIMESTAMP_FILE"
    DEPLOYED_NOW=1
else
    if [[ -f "$TIMESTAMP_FILE" ]]; then
        log "Local in sync (last build: $(cat "$TIMESTAMP_FILE"))"
    else
        log "Local in sync (no previous timestamp found)"
    fi
fi

# Runs every time, so a missed reboot schedule heals itself.
STEP="reboot check"
if [[ "$(readlink /run/booted-system/kernel)" != "$(readlink /run/current-system/kernel)" ]] || \
   [[ "$(readlink /run/booted-system/initrd)" != "$(readlink /run/current-system/initrd)" ]]; then
    if systemctl is-active --quiet gitops-reboot.timer; then
        log "Kernel or initrd changed, reboot already scheduled"
    else
        log "Kernel or initrd changed, scheduling reboot for 03:00..."
        STEP="reboot scheduling"
        run systemd-run --unit=gitops-reboot --on-calendar="03:00" systemctl reboot
    fi
fi

if (( DEPLOYED_NOW )); then
    STEP="success notification"
    notify "$SUCCESS_URL" \
        "Update completed successfully on ${HOSTNAME}." \
        default
fi