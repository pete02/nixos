#!/usr/bin/env bash
#
# bitwarden-backup: stop Bitwarden -> zip its data folder -> upload to Google Drive
#                   -> keep only the newest N backups.
#
# Standalone: needs docker (or systemctl), zip, rclone, grep, coreutils and curl on PATH.
# All configuration comes from environment variables.
#
# Usage:
#   bitwarden-backup            run a backup
#   bitwarden-backup --check    only verify that the required tools are installed
#
# Environment (defaults in brackets):
#   DATA_DIR              folder to back up                              [/opt/bitwarden/data]
#   CONTAINER_NAME        docker container to stop/start                 [bitwarden]
#   SYSTEMD_UNIT          if set, stop/start this unit via systemctl instead of docker
#   RCLONE_REMOTE         rclone destination, remote:folder              [gdrive:bitwarden-backups]
#   KEEP                  how many backups to keep                       [5]
#   NTFY_URL              ntfy notification URL                           [https://ntfy.lumilukko.com/Raysha]
#
# rclone credentials:
#   RCLONE_CONFIG         optional path to an existing rclone configuration
#   RCLONE_TOKEN_FILE     optional file containing the Google Drive OAuth token JSON
#   RCLONE_CLIENT_ID_FILE optional file containing your own OAuth client id
#   RCLONE_CLIENT_SECRET_FILE optional file containing your own OAuth client secret
#
# When RCLONE_CONFIG is set, rclone uses that configuration file directly.
# Otherwise, if RCLONE_TOKEN_FILE is set, the remote is configured using
# rclone's RCLONE_CONFIG_<NAME>_* environment variables.

set -Eeuo pipefail

DATA_DIR="${DATA_DIR:-/opt/bitwarden/data}"
CONTAINER_NAME="${CONTAINER_NAME:-bitwarden}"
SYSTEMD_UNIT="${SYSTEMD_UNIT:-}"
RCLONE_REMOTE="${RCLONE_REMOTE:-gdrive:bitwarden-backups}"
KEEP="${KEEP:-5}"
NTFY_URL="${NTFY_URL:-https://ntfy.lumilukko.com/Aria}"

WORK_DIR=""
BACKUP_NAME=""
BACKUP_PATH=""
STOPPED=0
FAILURE_CONTEXT="Backup failed before completion"
NOTIFICATION_SENT=0


log() {
    echo "[$(date '+%F %T')] $*"
}

notify() {
    local title="${1:-Bitwarden backup notification}"
    local message="${2:-No details provided}"

    [[ -n "$NTFY_URL" ]] || return 0
    command -v curl >/dev/null 2>&1 || return 0

    curl -fsS \
        --connect-timeout 5 \
        --max-time 10 \
        -H "Title: $title" \
        -H "Priority: high" \
        -d "$message" \
        "$NTFY_URL" >/dev/null || {
            log "WARNING: failed to send ntfy notification"
            return 0
        }
}

check_dependencies() {
    local missing=0 cmd
    local required=(zip rclone grep sort head date mktemp rm hostname curl)

    if [[ -n "$SYSTEMD_UNIT" ]]; then
        required+=(systemctl)
    else
        required+=(docker)
    fi

    for cmd in "${required[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo "bitwarden-backup: missing required command: $cmd" >&2
            missing=1
        fi
    done

    # Notifications are best-effort; curl is not required for the backup itself.
    return "$missing"
}

setup_rclone_remote() {
    [[ -n "${RCLONE_TOKEN_FILE:-}" ]] || return 0

    local name upper
    name="${RCLONE_REMOTE%%:*}"
    upper="${name^^}"

    export "RCLONE_CONFIG_${upper}_TYPE=drive"
    export "RCLONE_CONFIG_${upper}_SCOPE=drive.file"
    export "RCLONE_CONFIG_${upper}_TOKEN=$(< "$RCLONE_TOKEN_FILE")"

    if [[ -n "${RCLONE_CLIENT_ID_FILE:-}" ]]; then
        export "RCLONE_CONFIG_${upper}_CLIENT_ID=$(< "$RCLONE_CLIENT_ID_FILE")"
    fi

    if [[ -n "${RCLONE_CLIENT_SECRET_FILE:-}" ]]; then
        export "RCLONE_CONFIG_${upper}_CLIENT_SECRET=$(< "$RCLONE_CLIENT_SECRET_FILE")"
    fi
}

stop_service() {
    if [[ -n "$SYSTEMD_UNIT" ]]; then
        systemctl stop "$SYSTEMD_UNIT"
    else
        docker stop "$CONTAINER_NAME" >/dev/null
    fi
}

start_service() {
    if [[ -n "$SYSTEMD_UNIT" ]]; then
        systemctl start "$SYSTEMD_UNIT"
    else
        docker start "$CONTAINER_NAME" >/dev/null
    fi
}

on_error() {
    local status=$1
    local line=$2
    local command=$3

    # Preserve the first failure as the primary cause.
    if [[ "$FAILURE_CONTEXT" == "Backup failed before completion" ]]; then
        FAILURE_CONTEXT="Command failed at line $line (exit status $status): $command"
    fi

    return "$status"
}

cleanup() {
    local status=$?

    # Prevent recursive EXIT handling during cleanup.
    trap - EXIT
    

    if [[ "$STOPPED" -eq 1 ]]; then
        log "Starting Bitwarden again..."

        if start_service; then
            STOPPED=0
            log "Bitwarden restarted successfully."
        else
            log "ERROR: failed to restart Bitwarden!"
            notify \
                "Bitwarden restart FAILED" \
                "Host: $(hostname)
The backup script could not restart Bitwarden.
Primary failure: $FAILURE_CONTEXT
Check: journalctl -u bitwarden-backup.service"

            status=1
        fi
    fi

    if [[ -n "$WORK_DIR" ]]; then
        rm -rf -- "$WORK_DIR" || {
            log "WARNING: failed to remove temporary directory: $WORK_DIR"
            [[ "$status" -ne 0 ]] || status=1
        }
    fi

    if [[ "$status" -ne 0 ]]; then
        log "ERROR: $FAILURE_CONTEXT"

        if [[ "$NOTIFICATION_SENT" -eq 0 ]]; then
            NOTIFICATION_SENT=1
            notify \
                "Bitwarden backup FAILED" \
                "Host: $(hostname)
Context: $FAILURE_CONTEXT
Exit status: $status
Check: journalctl -u bitwarden-backup.service"
        fi
    fi

    exit "$status"
}

case "${1:-}" in
    --check)
        check_dependencies
        exit 0
        ;;
    -h|--help)
        sed -n '2,35p' "$0" | sed 's/^# \{0,1\}//'
        exit 0
        ;;
    "")
        ;;
    *)
        echo "bitwarden-backup: unknown argument: $1 (try --help)" >&2
        exit 2
        ;;
esac

# Install traps before preflight checks so runtime failures are reported.
trap 'on_error "$?" "$LINENO" "$BASH_COMMAND"' ERR
trap cleanup EXIT

check_dependencies

[[ -d "$DATA_DIR" ]] || {
    echo "bitwarden-backup: data folder not found: $DATA_DIR" >&2
    exit 1
}

[[ "$KEEP" =~ ^[1-9][0-9]*$ ]] || {
    echo "bitwarden-backup: KEEP must be a positive integer" >&2
    exit 1
}

if [[ -n "${RCLONE_TOKEN_FILE:-}" ]]; then
    [[ -r "$RCLONE_TOKEN_FILE" ]] || {
        echo "bitwarden-backup: token file is not readable" >&2
        exit 1
    }
fi

setup_rclone_remote

WORK_DIR="$(mktemp -d)"
BACKUP_NAME="bitwarden-backup-$(date +%Y-%m-%d_%H-%M-%S).zip"
BACKUP_PATH="$WORK_DIR/$BACKUP_NAME"

# 1. Stop Bitwarden
log "Stopping Bitwarden..."
stop_service
STOPPED=1

# 2. Zip the data folder
log "Creating $BACKUP_NAME..."
(
    cd "$DATA_DIR"
    zip -r -q "$BACKUP_PATH" .
)

[[ -s "$BACKUP_PATH" ]] || {
    echo "bitwarden-backup: archive is missing or empty" >&2
    exit 1
}

# The data is safely copied, so restart the service before uploading.
log "Starting Bitwarden..."
start_service
STOPPED=0

# 3. Upload to Google Drive
log "Uploading to $RCLONE_REMOTE..."
rclone copyto "$BACKUP_PATH" "$RCLONE_REMOTE/$BACKUP_NAME"

# 4. Prune old backups, keeping the newest KEEP files.
log "Pruning old backups (keeping $KEEP)..."

# Store the listing before pruning. This ensures listing failures are not
# accidentally hidden by a pipeline or an empty grep result.
REMOTE_FILES="$(rclone lsf --files-only "$RCLONE_REMOTE")"

mapfile -t BACKUPS < <(
    printf '%s\n' "$REMOTE_FILES" |
        grep -E '^bitwarden-backup-.*\.zip$' |
        sort || true
)

BACKUP_COUNT="${#BACKUPS[@]}"

if (( BACKUP_COUNT > KEEP )); then
    DELETE_COUNT=$((BACKUP_COUNT - KEEP))

    for ((i = 0; i < DELETE_COUNT; i++)); do
        old_file="${BACKUPS[$i]}"
        log "Deleting $old_file"
        rclone deletefile "$RCLONE_REMOTE/$old_file"
    done
fi

log "Backup finished successfully."
