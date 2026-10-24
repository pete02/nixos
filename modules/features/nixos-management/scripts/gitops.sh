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
STEP="initialization"

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
        "$url" || echo "WARNING: Failed to send ntfy notification" >&2
}

on_exit() {
    local rc=$?

    if (( rc != 0 )); then
        notify "$FAILURE_URL" \
            "Update failed on ${HOSTNAME:-unknown} during: ${STEP} (exit code: ${rc})" \
            high
    fi
}

check() {
    local cmd
    for cmd in curl git ssh nixos-rebuild systemd-run systemctl readlink; do
        echo "Checking ${cmd}..."
        command -v "$cmd" >/dev/null || return 1
    done
}

if [[ "${1:-}" == "--check" ]]; then
    check
    exit $?
fi

trap on_exit EXIT

STEP="preparation"
mkdir -p "$STATE_DIR"

if [[ ! -d "$REPO/.git" ]]; then
    STEP="initial clone"
    echo "No local clone found, cloning ${REPO_URL}..."
    git clone --branch "$BRANCH" "$REPO_URL" "$REPO"
fi

cd "$REPO"

STEP="fetch"
git fetch origin "$BRANCH"

STEP="revision check"
REMOTE="$(git rev-parse "origin/${BRANCH}")"
DEPLOYED="$(cat "$REV_FILE" 2>/dev/null || true)"

DEPLOYED_NOW=0

if [[ "$REMOTE" != "$DEPLOYED" ]]; then
    echo "Remote has updates (${DEPLOYED:-none} -> ${REMOTE}), triggering autoupdater"

    STEP="reset"
    git reset --hard "origin/${BRANCH}"

    STEP="NixOS rebuild"
    nixos-rebuild switch --flake "${REPO}#${HOSTNAME:?HOSTNAME is required}"

    # Only record the revision after a successful switch, so failures retry.
    echo "$REMOTE" > "$REV_FILE"
    date -Iseconds > "$TIMESTAMP_FILE"
    DEPLOYED_NOW=1
else
    if [[ -f "$TIMESTAMP_FILE" ]]; then
        echo "Local in sync (last build: $(cat "$TIMESTAMP_FILE"))"
    else
        echo "Local in sync (no previous timestamp found)"
    fi
fi

# Runs every time, so a missed reboot schedule heals itself.
STEP="reboot check"
if [[ "$(readlink /run/booted-system/kernel)" != "$(readlink /run/current-system/kernel)" ]] || \
   [[ "$(readlink /run/booted-system/initrd)" != "$(readlink /run/current-system/initrd)" ]]; then
    if systemctl is-active --quiet gitops-reboot.timer; then
        echo "Kernel or initrd changed, reboot already scheduled"
    else
        echo "Kernel or initrd changed, scheduling reboot for 03:00..."
        STEP="reboot scheduling"
        systemd-run --unit=gitops-reboot --on-calendar="03:00" systemctl reboot
    fi
fi

if (( DEPLOYED_NOW )); then
    STEP="success notification"
    notify "$SUCCESS_URL" \
        "Update completed successfully on ${HOSTNAME}." \
        default
fi