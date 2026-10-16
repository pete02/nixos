#!/usr/bin/env bash
set -euo pipefail

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

TIMESTAMP_FILE="/var/lib/gitops/last-sync"
mkdir -p /var/lib/gitops

export GIT_SSH_COMMAND="ssh -i /etc/ssh/id_server -o IdentitiesOnly=yes"
cd /etc/nixos

git fetch origin stable
LOCAL="$(git rev-parse @)"
REMOTE="$(git rev-parse origin/stable)"

if [ "$LOCAL" != "$REMOTE" ]; then
    echo "Remote has updates, triggering autoupdater"
    git reset --hard origin/stable

    nixos-rebuild switch --flake "/etc/nixos#$HOSTNAME" || \
        echo "Rebuild had warnings/errors, continuing anyway"

    date -Iseconds > "$TIMESTAMP_FILE"

    if [ "$(readlink /run/booted-system/kernel)" != "$(readlink /run/current-system/kernel)" ] || \
       [ "$(readlink /run/booted-system/initrd)" != "$(readlink /run/current-system/initrd)" ]; then
        echo "Kernel or initrd changed, scheduling reboot for 03:00..."
        systemd-run --on-calendar="03:00" systemctl reboot
    fi
else
    if [ -f "$TIMESTAMP_FILE" ]; then
        echo "Local in sync (last build: $(cat "$TIMESTAMP_FILE"))"
    else
        echo "Local in sync (no previous timestamp found)"
    fi
fi