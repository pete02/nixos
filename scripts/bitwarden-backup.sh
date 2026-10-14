#!/usr/bin/env bash
#
# bitwarden-backup: stop Bitwarden -> zip its data folder -> upload to Google Drive
#                   -> keep only the newest N backups.
#
# Standalone: needs docker (or systemctl), zip, rclone, grep and coreutils on PATH.
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
#
# rclone credentials (optional; if none are given, an existing rclone config is used):
#   RCLONE_TOKEN_FILE          file containing the Google Drive OAuth token JSON
#   RCLONE_CLIENT_ID_FILE      file containing your own OAuth client id (optional)
#   RCLONE_CLIENT_SECRET_FILE  file containing your own OAuth client secret (optional)
# When RCLONE_TOKEN_FILE is set, the remote named in RCLONE_REMOTE is defined on the
# fly through rclone's RCLONE_CONFIG_<NAME>_* variables, so no rclone.conf is needed.

set -euo pipefail

DATA_DIR="${DATA_DIR:-/opt/bitwarden/data}"
CONTAINER_NAME="${CONTAINER_NAME:-bitwarden}"
SYSTEMD_UNIT="${SYSTEMD_UNIT:-}"
RCLONE_REMOTE="${RCLONE_REMOTE:-gdrive:bitwarden-backups}"
KEEP="${KEEP:-5}"

log() { echo "[$(date '+%F %T')] $*"; }

NTFY_URL="${NTFY_URL:-https://ntfy.lumilukko.com/Raysha}"

notify() {
    [[ -n "$NTFY_URL" ]] || return 0
    command -v curl >/dev/null 2>&1 || return 0

    curl -fsS \
        --connect-timeout 5 \
        --max-time 10 \
        -H "Title: $1" \
        -H "Priority: high" \
        -d "$2" \
        "$NTFY_URL" >/dev/null || true
}

FAILURE_CONTEXT="Backup failed before completion"

on_error() {
    local status=$1 line=$2
    FAILURE_CONTEXT="Failed at line $line (exit status $status)"
}

cleanup() {
    local status=$?

    # Prevent recursive EXIT handling while cleanup runs.
    trap - EXIT

    if [[ "$STOPPED" -eq 1 ]]; then
        log "Starting Bitwarden again..."
        if start_service; then
            STOPPED=0
        else
            log "ERROR: failed to restart Bitwarden!"
            notify "Bitwarden restart FAILED" \
                "The backup script could not restart Bitwarden on $(hostname). Check the systemd journal."
            status=1
        fi
    fi

    rm -rf "$WORK_DIR"

    if [[ "$status" -ne 0 ]]; then
        log "ERROR: $FAILURE_CONTEXT"
        notify "Bitwarden backup FAILED" \
            "Host: $(hostname)
Context: $FAILURE_CONTEXT
Exit status: $status
Check: journalctl -u bitwarden-backup.service"
    fi

    exit "$status"
}


check_dependencies() {
    local missing=0 cmd
    local required=(zip rclone grep sort head date mktemp rm dirname)

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

case "${1:-}" in
    --check)
        check_dependencies
        exit 0
        ;;
    -h|--help)
        sed -n '2,27p' "$0" | sed 's/^# \{0,1\}//'
        exit 0
        ;;
    "")
        ;;
    *)
        echo "bitwarden-backup: unknown argument: $1 (try --help)" >&2
        exit 2
        ;;
esac

check_dependencies
[[ -d "$DATA_DIR" ]] || { echo "bitwarden-backup: data folder not found: $DATA_DIR" >&2; exit 1; }
[[ "$KEEP" =~ ^[1-9][0-9]*$ ]] || { echo "bitwarden-backup: KEEP must be a positive integer" >&2; exit 1; }

setup_rclone_remote

WORK_DIR="$(mktemp -d)"
BACKUP_NAME="bitwarden-backup-$(date +%Y-%m-%d_%H-%M-%S).zip"
BACKUP_PATH="$WORK_DIR/$BACKUP_NAME"
STOPPED=0

# Always bring Bitwarden back and remove temp files, even if a step fails.
cleanup() {
    if [[ "$STOPPED" -eq 1 ]]; then
        log "Starting Bitwarden again..."
        start_service || log "WARNING: failed to start Bitwarden!"
    fi
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

# 1. Stop Bitwarden
log "Stopping Bitwarden..."
stop_service
STOPPED=1

# 2. Zip the data folder
log "Creating $BACKUP_NAME..."
(cd "$DATA_DIR" && zip -r -q "$BACKUP_PATH" .)

# The data is safely copied, so restart the service before uploading
log "Starting Bitwarden..."
start_service
STOPPED=0

# 3. Upload to Google Drive
log "Uploading to $RCLONE_REMOTE..."
rclone copy "$BACKUP_PATH" "$RCLONE_REMOTE"

# 4. Keep only the newest $KEEP backups (file names contain a sortable timestamp)
log "Pruning old backups (keeping $KEEP)..."
rclone lsf --files-only "$RCLONE_REMOTE" \
    | grep -E '^bitwarden-backup-.*\.zip$' \
    | sort \
    | head -n -"$KEEP" \
    | while read -r old_file; do
        log "Deleting $old_file"
        rclone deletefile "$RCLONE_REMOTE/$old_file"
    done

log "Backup finished successfully."
