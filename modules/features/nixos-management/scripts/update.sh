#!/usr/bin/env bash
set -euo pipefail

REPOSITORY="@REPOSITORY@"
PULL_BRANCH="${PULL_BRANCH:-stable}"
PUSH_BRANCH="${PUSH_BRANCH:-master}"

check() {
    local cmd
    for cmd in git nix ssh mktemp; do
        echo "Checking ${cmd}..."
        command -v "$cmd" >/dev/null || return 1
    done

    echo "All dependencies available."
}

if [[ "${1:-}" == "--check" ]]; then
    check
    exit $?
fi

check

TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

echo "Checking out $PULL_BRANCH..."
git clone \
    --branch "$PULL_BRANCH" \
    --single-branch \
    "$REPOSITORY" \
    "$TEMP_DIR/repo"

cd "$TEMP_DIR/repo"

echo "Updating flake inputs..."
nix flake update

if git diff --quiet -- flake.lock; then
    echo "No flake updates available."
    exit 0
fi

echo "Committing flake.lock..."
git add flake.lock
git commit -m "Update flake inputs"

echo "Pushing to $PUSH_BRANCH..."
git push origin "HEAD:$PUSH_BRANCH"

echo "Flake update pushed successfully."
