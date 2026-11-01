
#!/usr/bin/env bash
set -Eeuo pipefail
REPOSITORY=@REPOSITORY@
PASSWORD_FILE=@PASSWORD_FILE@
FOLDERS=(@FOLDERS@)
EXCLUDES=(@EXCLUDES@)
EXTRA_ARGS=(@EXTRA_ARGS@)
PRUNE_OPTS=(@PRUNE_OPTS@)
NTFY_SUCCESS=@NTFY_SUCCESS@
NTFY_FAILURE=@NTFY_FAILURE@

export RESTIC_REPOSITORY="$REPOSITORY"
export RESTIC_PASSWORD_FILE="$PASSWORD_FILE"
export RESTIC_PROGRESS_FPS="${RESTIC_PROGRESS_FPS:-0.0333}"
NOTIFY_ON_FAILURE="${NOTIFY_ON_FAILURE:-1}"



if [[ "${1:-}" == "--check" ]]; then
  for command in restic flock curl hostname; do
    if ! command -v "$command" >/dev/null 2>&1; then
      echo "Missing runtime dependency: $command" >&2
      exit 1
    fi
  done

  echo "All Restic backup runtime dependencies are available."
  exit 0
fi



notify() {
  local url="$1"
  local message="$2"

  if [[ -n "$url" ]]; then
    curl \
      --fail \
      --silent \
      --show-error \
      --retry 3 \
      --retry-delay 3 \
      --retry-all-errors \
      --max-time 20 \
      --data-binary "$message" \
      "$url" || echo "WARNING: failed to send ntfy notification" >&2
  fi
}

on_exit() {
  local status=$?
  trap - EXIT

  if (( status != 0 )) && [[ "$NOTIFY_ON_FAILURE" == 1 ]]; then
    notify "$NTFY_FAILURE" \
      "Restic backup failed on $(hostname) during (exit code $status)."
  fi

  exit "$status"
}

trap on_exit EXIT
trap 'exit 143' TERM
trap 'exit 130' INT HUP



# Both scheduled and shutdown runs use the same lock.
LOCKFILE="${LOCKFILE:-/run/restic-backup/lock}"
exec 9>"$LOCKFILE"

if ! flock -n 9; then
  echo "Another Restic backup is already running; skipping."
  exit 0
fi

# Do not initialize automatically: a failed connection must not be
# mistaken for an uninitialized repository.
restic snapshots >/dev/null
set +e
restic backup \
  --verbose \
  "${EXTRA_ARGS[@]}" \
  "${EXCLUDES[@]}" \
  "${FOLDERS[@]}"
rc=$?
set -e
if (( rc != 0 && rc != 3 )); then exit "$rc"; fi

echo "Backup done"

restic forget \
  --retry-lock 15m \
  "${PRUNE_OPTS[@]}" \
  --prune

notify "$NTFY_SUCCESS" \
  "Restic backup completed successfully on $(hostname)."
