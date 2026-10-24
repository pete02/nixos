#!/usr/bin/env bash
#
# rsync-backup.sh - back up folders to a destination with rsync.
#
# Usage:
#   rsync-backup.sh [options]
#
# The destination, folders and other settings are filled in by Nix at build time.
#
# Options:
#   -n           Dry run: show what would be transferred, change nothing
#   -h           Show this help
#   --check      Verify that all required commands are available, then exit.
#                Exits 0 if all good, 1 if something is missing.
#
# Notes:
#   - Source paths are recreated under the destination (rsync --relative), so
#     /home/alice/code ends up at <destination>/home/alice/code.
#   - Only one backup runs at a time; a second one waits for the first to finish.
#   - Files that vanish while being copied are not treated as an error.
#   - A failure in one folder does not stop the others.
#   - When run in a terminal, live progress (percentage, speed, ETA) is shown
#     for each folder. Non-interactive runs (timers) keep plain logs.
#   - If configured, an ntfy message is sent when the backup finishes: one URL
#     for success and one for failure (either may be empty to disable it).
#     Dry runs never send notifications.

set -u

DESTINATION=@DESTINATION@
DELETE=@DELETE@
FOLDERS=(@FOLDERS@)
EXCLUDES=(@EXCLUDES@)
EXTRA_ARGS=(@EXTRA_ARGS@)
NTFY_SUCCESS=@NTFY_SUCCESS@   # full ntfy URL (e.g. https://ntfy.sh/topic), empty = off
NTFY_FAILURE=@NTFY_FAILURE@   # full ntfy URL, empty = off
DRY_RUN=0
LOCKFILE="${LOCKFILE:-${XDG_RUNTIME_DIR:-/tmp}/rsync-backup.lock}"

usage() {
  # Print the header comment above (everything up to the first non-comment line).
  sed -n '3,/^[^#]/{/^#/p}' "$0" | sed 's/^# \{0,1\}//'
}

# External commands this script relies on. ssh is only needed for remote destinations,
# curl only when at least one ntfy URL is configured.
REQUIRED_CMDS=(rsync flock date sed)
if [[ "$DESTINATION" == *:* && "$DESTINATION" != /* && "$DESTINATION" != rsync://* ]]; then
  REQUIRED_CMDS+=(ssh)
fi
if [ -n "$NTFY_SUCCESS" ] || [ -n "$NTFY_FAILURE" ]; then
  REQUIRED_CMDS+=(curl)
fi

check_requirements() {
  # Prints a status line per command. Returns 0 if all are present, 1 otherwise.
  local cmd missing=0
  for cmd in "${REQUIRED_CMDS[@]}"; do
    if command -v "$cmd" >/dev/null 2>&1; then
      echo "  [ok]      $cmd"
    else
      echo "  [MISSING] $cmd"
      missing=$((missing + 1))
    fi
  done
  return "$([ "$missing" -eq 0 ] && echo 0 || echo 1)"
}

# Send an ntfy message. Usage: notify <url> <title> <tags> <priority> <body>
# Does nothing if the URL is empty. A failed notification never fails the backup.
notify() {
  local url=$1 title=$2 tags=$3 priority=$4 body=$5
  [ -n "$url" ] || return 0
  if ! curl -fsS --max-time 15 \
      -H "Title: $title" \
      -H "Tags: $tags" \
      -H "Priority: $priority" \
      -d "$body" \
      "$url" >/dev/null; then
    echo "Warning: could not send ntfy notification." >&2
  fi
}

# --check is a long option, which getopts doesn't handle, so look for it first.
for arg in "$@"; do
  if [ "$arg" = "--check" ]; then
    echo "Checking required commands..."
    if check_requirements; then
      echo "All required commands are available."
      exit 0
    else
      echo "Some required commands are missing. Install them and try again." >&2
      exit 1
    fi
  fi
done

while getopts ":nh" opt; do
  case "$opt" in
    n) DRY_RUN=1 ;;
    h) usage; exit 0 ;;
    \?) echo "Unknown option: -$OPTARG" >&2; usage; exit 2 ;;
  esac
done
shift $((OPTIND - 1))

if [ $# -gt 0 ]; then
  echo "Error: unexpected argument '$1'." >&2
  usage
  exit 2
fi

if [ -z "$DESTINATION" ]; then
  echo "Error: no destination configured." >&2
  exit 2
fi

if [ "${#FOLDERS[@]}" -eq 0 ]; then
  echo "Error: no folders to back up." >&2
  exit 2
fi

if ! check_requirements >/dev/null; then
  echo "Error: required commands are missing. Run with --check for details." >&2
  exit 2
fi

# Only one backup at a time (the daily run and the shutdown run could overlap).
if ! ( : >>"$LOCKFILE" ) 2>/dev/null; then
  echo "Error: cannot create lock file '$LOCKFILE'." >&2
  exit 2
fi
exec 9>>"$LOCKFILE"
if ! flock -n 9; then
  echo "Another backup is running, waiting for it to finish..."
  flock 9
fi

# Build the rsync arguments shared by every folder.
args=(-a --relative --mkpath --partial --info=stats1)
if [ "$DELETE" = "1" ]; then
  args+=(--delete)
fi
for pattern in "${EXCLUDES[@]}"; do
  args+=("--exclude=$pattern")
done
if [ "$DRY_RUN" -eq 1 ]; then
  args+=(--dry-run --itemize-changes)
  echo "DRY RUN: no files will be changed."
fi
args+=("${EXTRA_ARGS[@]}")

# Live progress (overall percentage, speed, ETA) only when run in a terminal, so
# logs from the timer or shutdown run stay clean. --no-inc-recursive makes rsync
# scan the folder up front, which gives an accurate percentage and ETA.
if [ -t 1 ]; then
  args+=(--human-readable --info=progress2 --no-inc-recursive)
fi

echo "Backing up to $DESTINATION"
echo

ok=0
failed=0
failed_folders=()
total=${#FOLDERS[@]}
idx=0
for folder in "${FOLDERS[@]}"; do
  idx=$((idx + 1))
  echo "==> [$idx/$total] $folder"

  if [ ! -e "$folder" ]; then
    echo "    does not exist, skipping"
    failed=$((failed + 1))
    failed_folders+=("$folder (does not exist)")
    continue
  fi

  rsync "${args[@]}" -- "$folder" "$DESTINATION"
  rc=$?

  case "$rc" in
    0)
      echo "    done"
      ok=$((ok + 1))
      ;;
    24)
      echo "    done (some files vanished while copying, which is normal for live data)"
      ok=$((ok + 1))
      ;;
    *)
      echo "    FAILED (rsync exit code $rc)"
      failed=$((failed + 1))
      failed_folders+=("$folder (rsync exit code $rc)")
      ;;
  esac
  echo
done

summary="Folders: ${#FOLDERS[@]} | ok: $ok | failed: $failed"
echo "Done. $summary"

if [ "$DRY_RUN" -eq 0 ]; then
  host="${HOSTNAME:-unknown}"
  if [ "$failed" -eq 0 ]; then
    notify "$NTFY_SUCCESS" \
      "Backup succeeded on $host" \
      "white_check_mark" \
      "default" \
      "Backed up to $DESTINATION. $summary"
  else
    body="Backup to $DESTINATION had failures. $summary"
    for f in "${failed_folders[@]}"; do
      body+=$'\n'"- $f"
    done
    notify "$NTFY_FAILURE" \
      "Backup FAILED on $host" \
      "x,warning" \
      "high" \
      "$body"
  fi
fi

[ "$failed" -eq 0 ]