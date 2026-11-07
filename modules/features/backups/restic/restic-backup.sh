
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
  for command in restic flock curl hostname mountpoint; do
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

# Send a specific failure message and exit, suppressing the generic
# on_exit notification so the cause is reported only once.
notify_fail() {
  local message="$1"
  NOTIFY_ON_FAILURE=0
  notify "$NTFY_FAILURE" "$message"
  exit 1
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

# 1. refuse to touch an unmounted share (local repositories only).
# Walk up the repository path so a subdirectory of a mounted share
# still counts as mounted, but never accept "/" itself.
if [[ "$REPOSITORY" == /* ]]; then
  p="$REPOSITORY"
  mounted=0
  while [[ -n "$p" && "$p" != "/" ]]; do
    if mountpoint -q "$p" 2>/dev/null; then
      mounted=1
      break
    fi
    p="${p%/*}"
  done
  if (( mounted == 0 )); then
    notify_fail "share not mounted for repository $REPOSITORY"
  fi
fi

# 2. does a repo exist? restic >= 0.17 exits 10 when the repository
# is reachable but not initialized; any other non-zero exit is a hard
# failure (bad connection, unreadable password, etc).
rc=0
restic unlock || true
restic cat config >/dev/null || rc=$?
case "$rc" in
  0) ;;                                       # repo is fine
  10) restic init && notify "$NTFY_SUCCESS" "restic repo created on $(hostname)" ;;
  *) notify_fail "repo check failed (exit $rc)" ;;
esac

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
