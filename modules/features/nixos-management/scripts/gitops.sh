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

# System generations to keep, including the one being deployed. Fewer
# generations means fewer boot entries (and kernels) to store on the SD card.
KEEP_GENERATIONS="${KEEP_GENERATIONS:-2}"

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
    for cmd in curl git ssh nix-store nix-env nix-collect-garbage systemd-run systemctl readlink df; do
        echo "Checking ${cmd}..."
        command -v "$cmd" >/dev/null || return 1
    done
}

report_boot_space() {
    echo "Boot space (${1}):"
    # df on /boot/firmware also triggers its automount.
    df -h /boot /boot/firmware 2>&1 || true
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
        # Make room first: drop old generations so the bootloader only has to
        # keep KEEP_GENERATIONS entries once this one is added. The switch
        # below regenerates the boot entries from the remaining generations.
        STEP="prune old generations"
        report_boot_space "before prune"
        nix-env -p /nix/var/nix/profiles/system \
            --delete-generations "+$(( KEEP_GENERATIONS > 1 ? KEEP_GENERATIONS - 1 : 1 ))"

        # Realise through substituters: Attic for our own paths, and the normal
        # upstream cache for everything else. Attic does not store paths that
        # cache.nixos.org already has, so a plain `nix copy --from attic` fails
        # on those dependencies ("path ... is not valid").
        # Fails (and aborts the run) if any path is unavailable or its signature
        # is not from a trusted key. Signature checking stays on.
        STEP="fetch closure from cache"
        nix-store --realise \
            --option extra-substituters "$CACHE_URL" \
            "$TARGET" >/dev/null

        if [[ ! -x "$TARGET/bin/switch-to-configuration" ]]; then
            echo "ERROR: ${TARGET} has no switch-to-configuration" >&2
            exit 1
        fi

        STEP="set system profile"
        nix-env -p /nix/var/nix/profiles/system --set "$TARGET"

        # Run in its own transient unit so the switch survives gitops being
        # restarted or stopped by the activation (same as nixos-rebuild).
        STEP="switch to configuration"
        if ! systemd-run \
            --unit=gitops-switch \
            --collect \
            --wait \
            --pipe \
            --quiet \
            --no-ask-password \
            --service-type=exec \
            "$TARGET/bin/switch-to-configuration" switch; then
            # A failed bootloader install can leave the boot partition half
            # written. Show the space so the cause is visible in the journal.
            report_boot_space "after failed switch"
            echo "ERROR: switch failed; do NOT reboot until it succeeds" >&2
            exit 1
        fi
    fi

    # Only record the path after a successful switch, so failures retry.
    echo "$TARGET" > "$PATH_FILE"
    date -Iseconds > "$TIMESTAMP_FILE"
    DEPLOYED_NOW=1

    # Non-fatal: the deploy already succeeded, this only reclaims disk space.
    STEP="garbage collection"
    nix-collect-garbage >/dev/null || echo "WARNING: garbage collection failed" >&2
    report_boot_space "after deploy"
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