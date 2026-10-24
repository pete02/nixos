#!/usr/bin/env bash
#
# git-sync.sh - find git repos under one or more folders, commit any changes, and push.
#
# Usage:
#   git-sync.sh [options] [folder...]
#
# The folders to scan (and the default message and depth) are filled in by Nix at
# build time. Folders given on the command line replace the built-in list.
#
# Options:
#   -m MESSAGE   Commit message (default: "Auto-commit: <timestamp>")
#   -d DEPTH     Max directory depth to search for repos (default: 3)
#   -n           Dry run: show what would be done, change nothing
#   -h           Show this help
#   --check      Verify that all required commands are available, then exit
#                (no folder needed). Exits 0 if all good, 1 if something is missing.
#
# Environment:
#   NTFY_SUCCESS  Full ntfy topic URL (e.g. https://ntfy.sh/my-success-topic).
#                 If set, a notification is sent when the run finishes with no failures.
#   NTFY_FAILURE  Full ntfy topic URL (e.g. https://ntfy.sh/my-failure-topic).
#                 If set, a notification is sent when any repo or folder fails.
#                 Either can be left unset to disable that notification. They may point
#                 at the same topic. A failed notification never changes the exit code.
#
# Notes:
#   - Stages everything (git add -A), respecting each repo's .gitignore.
#   - Repos with nothing to commit still get pushed if they have unpushed commits.
#   - Repos with no remote, or in a detached HEAD state, are skipped with a note.
#   - A failure in one repo or folder does not stop the others.

set -u

MESSAGE=@MESSAGE@
DEPTH=@DEPTH@
DRY_RUN=0
FOLDERS=(@FOLDERS@)
NTFY_SUCCESS="@NTFY_SUCCESS@"
NTFY_FAILURE="@NTFY_FAILURE@"

usage() {
  # Print the header comment above (everything up to the first non-comment line).
  sed -n '3,/^[^#]/{/^#/p}' "$0" | sed 's/^# \{0,1\}//'
}

# External commands this script relies on.
REQUIRED_CMDS=(git find sort dirname grep head sed date)
# curl is only needed if notifications are enabled.
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

while getopts ":m:d:nh" opt; do
  case "$opt" in
    m) MESSAGE="$OPTARG" ;;
    d) DEPTH="$OPTARG" ;;
    n) DRY_RUN=1 ;;
    h) usage; exit 0 ;;
    :) echo "Option -$OPTARG requires an argument." >&2; exit 2 ;;
    \?) echo "Unknown option: -$OPTARG" >&2; usage; exit 2 ;;
  esac
done
shift $((OPTIND - 1))

# Folders on the command line replace the built-in list.
if [ $# -gt 0 ]; then
  FOLDERS=("$@")
fi

if [ "${#FOLDERS[@]}" -eq 0 ]; then
  echo "Error: no folders to scan." >&2
  usage
  exit 2
fi

if ! check_requirements >/dev/null; then
  echo "Error: required commands are missing. Run with --check for details." >&2
  exit 2
fi

committed=0
pushed=0
skipped=0
failed=0
clean=0

run() {
  # Run a command, or just print it in dry-run mode.
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "    [dry-run] $*"
    return 0
  fi
  "$@"
}

notify() {
  # notify URL TITLE BODY TAGS
  # Sends an ntfy notification. Does nothing if URL is empty. Never fails the script.
  local url="$1" title="$2" body="$3" tags="$4"
  [ -n "$url" ] || return 0

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] would notify $url: $title - $body"
    return 0
  fi

  if curl -fsS -m 15 \
       -H "Title: $title" \
       -H "Tags: $tags" \
       -d "$body" \
       "$url" >/dev/null; then
    echo "Notification sent."
  else
    echo "Warning: could not send notification to $url" >&2
  fi
}

process_repo() {
  local repo="$1"
  echo "==> $repo"

  cd "$repo" || { echo "    cannot enter directory"; failed=$((failed + 1)); return; }

  local branch
  branch="$(git symbolic-ref --short -q HEAD)"
  if [ -z "$branch" ]; then
    echo "    detached HEAD, skipping"
    skipped=$((skipped + 1))
    return
  fi

  local did_commit=0

  # Commit local changes (including untracked files).
  if [ -n "$(git status --porcelain)" ]; then
    local msg="${MESSAGE:-Auto-commit: $(date '+%Y-%m-%d %H:%M:%S')}"
    if run git add -A && run git commit -q -m "$msg"; then
      echo "    committed changes on '$branch'"
      committed=$((committed + 1))
      did_commit=1
    else
      echo "    commit FAILED (hooks, identity, or merge in progress?)"
      failed=$((failed + 1))
      return
    fi
  fi

  # Work out whether a push is needed and where to.
  if ! git remote | grep -q .; then
    echo "    no remote configured, skipping push"
    skipped=$((skipped + 1))
    return
  fi

  if git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
    local ahead
    ahead="$(git rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)"
    if [ "$ahead" -eq 0 ] && [ "$did_commit" -eq 0 ]; then
      echo "    nothing to commit or push"
      clean=$((clean + 1))
      return
    fi
    if run git push -q; then
      echo "    pushed"
      pushed=$((pushed + 1))
    else
      echo "    push FAILED (diverged branch or auth problem?)"
      failed=$((failed + 1))
    fi
  else
    # No upstream tracking branch: publish to 'origin' if present, else the first remote.
    local remote
    if git remote | grep -qx origin; then
      remote="origin"
    else
      remote="$(git remote | head -n 1)"
    fi
    if run git push -q -u "$remote" "$branch"; then
      echo "    pushed (set upstream to $remote/$branch)"
      pushed=$((pushed + 1))
    else
      echo "    push FAILED"
      failed=$((failed + 1))
    fi
  fi
}

[ "$DRY_RUN" -eq 1 ] && echo "DRY RUN: no changes will be made."

found=0
for folder in "${FOLDERS[@]}"; do
  if [ ! -d "$folder" ]; then
    echo "Error: '$folder' is not a directory, skipping." >&2
    failed=$((failed + 1))
    continue
  fi
  root="$(cd "$folder" && pwd)"

  echo "Scanning $root (max depth $DEPTH)..."
  echo

  # A repo is any directory containing a .git entry (dir or file, so worktrees and
  # submodules count). -prune stops find from descending into .git itself.
  while IFS= read -r gitpath; do
    found=$((found + 1))
    process_repo "$(dirname "$gitpath")"
    cd "$root" || break
  done < <(find "$root" -maxdepth "$((DEPTH + 1))" -name .git -prune -print 2>/dev/null | sort)

  echo
done

summary="Repos found: $found | committed: $committed | pushed: $pushed | up to date: $clean | skipped: $skipped | failed: $failed"
echo "Done. $summary"

if [ "$failed" -eq 0 ]; then
  notify "$NTFY_SUCCESS" "git-sync succeeded" "$summary" "white_check_mark"
  exit 0
else
  notify "$NTFY_FAILURE" "git-sync failed" "$summary" "warning"
  exit 1
fi