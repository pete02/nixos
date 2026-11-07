#!/usr/bin/env bash
set -euo pipefail

REPOSITORY="@REPOSITORY@"
# Update on top of master (the newest code), not stable: one broken host
# must not freeze flake updates for everyone.
PULL_BRANCH="${PULL_BRANCH:-master}"
PUSH_BRANCH="${PUSH_BRANCH:-master}"

check() {
    local cmd
    for cmd in git nix; do
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

git config user.email "aria@local"
git config --global user.name "aria auto updater"

echo "Committing flake.lock..."
git add flake.lock
git commit -m "Update flake inputs"

echo "Pushing to $PUSH_BRANCH..."
git push origin "HEAD:$PUSH_BRANCH"

echo "Flake update pushed successfully."