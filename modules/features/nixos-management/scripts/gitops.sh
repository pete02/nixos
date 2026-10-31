#!/usr/bin/env bash
set -euo pipefail

SUCCESS_URL="@NTFY_SUCCESS_URL@"
FAILURE_URL="@NTFY_FAILURE_URL@"
REPO_URL="@REPO_URL@"
CACHE_URL="@CACHE_URL@"

STATE_DIR="/var/lib/gitops"
# New directory on purpose: the old script tracked `stable` in $STATE_DIR/repo.
# That clone is no longer used and can be deleted.
REPO="$STATE_DIR/deploy-repo"
BRANCH="deploy"
TIMESTAMP_FILE="$STATE_DIR/last-sync"
PATH_FILE="$STATE_DIR/last-deployed-path"
HOST="${HOSTNAME:-$(cat /proc/sys/kernel/hostname)}"
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
            "Update failed on ${HOST} during: ${STEP} (exit code: ${rc})" \
            high
    fi
}

check() {
    local cmd
    for cmd in curl git ssh nix nix-env systemd-run systemctl readlink; do
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
    echo "No local clone found, cloning ${BRANCH} from ${REPO_URL}..."
    git clone --depth 1 --single-branch --branch "$BRANCH" "$REPO_URL" "$REPO"
fi

cd "$REPO"

STEP="fetch"
git fetch --depth 1 origin "$BRANCH"
git reset --hard "origin/${BRANCH}"

STEP="read target path"
HOST_FILE="$REPO/hosts/${HOST}"
if [[ ! -f "$HOST_FILE" ]]; then
    echo "ERROR: no entry for ${HOST} on ${BRANCH}" >&2
    exit 1
fi

TARGET="$(tr -d '[:space:]' < "$HOST_FILE")"
if [[ ! "$TARGET" =~ ^/nix/store/[0-9a-z]{32}-[^/[:space:]]+$ ]]; then
    echo "ERROR: invalid store path for ${HOST}: '${TARGET}'" >&2
    exit 1
fi

SOURCE="$(git log -1 --format=%s)"
DEPLOYED="$(cat "$PATH_FILE" 2>/dev/null || true)"

DEPLOYED_NOW=0

if [[ "$TARGET" != "$DEPLOYED" ]]; then
    echo "Target changed (${DEPLOYED:-none} -> ${TARGET}) [${SOURCE}]"

    if [[ "$(readlink -f /run/current-system)" == "$TARGET" ]]; then
        echo "Target is already the running system, recording it"
    else
        # Fails (and aborts the run) if CI never pushed this path, or if its
        # signature is not from a trusted key. No --no-check-sigs on purpose.
        STEP="fetch closure from cache"
        nix --extra-experimental-features nix-command \
            copy --from "$CACHE_URL" "$TARGET"

        if [[ ! -x "$TARGET/bin/switch-to-configuration" ]]; then
            echo "ERROR: ${TARGET} has no switch-to-configuration" >&2
            exit 1
        fi

        STEP="set system profile"
        nix-env -p /nix/var/nix/profiles/system --set "$TARGET"

        # Run in its own transient unit so the switch survives gitops being
        # restarted or stopped by the activation (same as nixos-rebuild).
        STEP="switch to configuration"
        systemd-run \
            --unit=gitops-switch \
            --collect \
            --wait \
            --pipe \
            --quiet \
            --no-ask-password \
            --service-type=exec \
            "$TARGET/bin/switch-to-configuration" switch
    fi

    # Only record the path after a successful switch, so failures retry.
    echo "$TARGET" > "$PATH_FILE"
    date -Iseconds > "$TIMESTAMP_FILE"
    DEPLOYED_NOW=1
else
    if [[ -f "$TIMESTAMP_FILE" ]]; then
        echo "Local in sync (last deploy: $(cat "$TIMESTAMP_FILE"))"
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
        "Update completed successfully on ${HOST} (${SOURCE})." \
        default
fi