#!/usr/bin/env bash
set -euo pipefail

CONFIG_FOLDER=/etc/nixos

cd "$CONFIG_FOLDER"

# Save current state so we can roll back if necessary
ORIGINAL_REV=$(git rev-parse HEAD)

cleanup() {
    echo "Restoring repository..."
    git restore .
    git clean -fd
    git reset --hard "$ORIGINAL_REV"
}

echo "Updating flake inputs..."
nix flake update

echo
echo "Validating every host..."

mapfile -t HOSTS < <(
    find modules/hosts -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort
)

for HOST in "${HOSTS[@]}"; do
    echo "----------------------------------------"
    echo "Dry-building $HOST"
    echo "----------------------------------------"

    if ! nixos-rebuild dry-build \
        --flake "$CONFIG_FOLDER#$HOST" \
        --impure \
        >/tmp/nixos-dry-build.log 2>&1
    then
        echo
        echo "Dry-build failed for $HOST."
        cleanup
        exit 1
    fi
done

echo
echo "All hosts build successfully."

echo
echo "Running rebuild..."
exec /run/current-system/sw/bin/rebuild