#!/usr/bin/env bash
set -euo pipefail

TIMESTAMP_FILE="/var/lib/gitops/last-sync"
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
    echo "Checking curl..."
    command -v curl >/dev/null || return 1

    echo "Checking git..."
    command -v git >/dev/null || return 1
}

if [[ "${1:-}" == "--check" ]]; then
    check
    exit $?
fi

trap on_exit EXIT

SUCCESS_URL="${NTFY_SUCCESS_URL:?NTFY_SUCCESS_URL is required}"
FAILURE_URL="${NTFY_FAILURE_URL:?NTFY_FAILURE_URL is required}"

STEP="preparation"
mkdir -p /var/lib/gitops

# Allow the system service to access the root-owned/foreign-owned
# repository without changing global Git configuration.
export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0="safe.directory"
export GIT_CONFIG_VALUE_0="/etc/nixos"

export GIT_SSH_COMMAND="ssh -i /etc/ssh/id_server -o IdentitiesOnly=yes"

cd /etc/nixos

STEP="fetch"
git fetch origin stable

STEP="revision check"
LOCAL="$(git rev-parse @)"
REMOTE="$(git rev-parse origin/stable)"

if [[ "$LOCAL" != "$REMOTE" ]]; then
    echo "Remote has updates, triggering autoupdater"

    STEP="reset"
    git reset --hard origin/stable

    STEP="NixOS rebuild"
    nixos-rebuild switch --flake "/etc/nixos#${HOSTNAME:?HOSTNAME is required}"

    date -Iseconds > "$TIMESTAMP_FILE"

    if [[ "$(readlink /run/booted-system/kernel)" != "$(readlink /run/current-system/kernel)" ]] || \
       [[ "$(readlink /run/booted-system/initrd)" != "$(readlink /run/current-system/initrd)" ]]; then
        echo "Kernel or initrd changed, scheduling reboot for 03:00..."

        STEP="reboot scheduling"
        systemd-run --on-calendar="03:00" systemctl reboot
    fi

    STEP="success notification"
    notify "$SUCCESS_URL" \
        "Update completed successfully on ${HOSTNAME}." \
        default

else
    if [[ -f "$TIMESTAMP_FILE" ]]; then
        echo "Local in sync (last build: $(cat "$TIMESTAMP_FILE"))"
    else
        echo "Local in sync (no previous timestamp found)"
    fi
fi