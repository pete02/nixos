#!/usr/bin/env bash
set -euo pipefail

CONFIG_FOLDER=/etc/nixos
GIT_USER=$(stat -c '%U' "$CONFIG_FOLDER/.git")

git_cmd() {
    if [[ $EUID -eq 0 ]]; then
        sudo -H -u "$GIT_USER" git "$@"
    else
        git "$@"
    fi
}




cd "$CONFIG_FOLDER"

# Save current state so we can roll back if necessary
ORIGINAL_REV=$(git_cmd rev-parse HEAD)

cleanup() {
    echo "Restoring repository..."
    git_cmd restore .
    git_cmd clean -fd
    git_cmd reset --hard "$ORIGINAL_REV"
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
        if [[ -S "/run/user/$UID/bus" ]]; then
            sudo -u "$GIT_USER" \
                XDG_RUNTIME_DIR="/run/user/$UID" \
                DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$UID/bus" \
                notify-send \
                "NixOS Updated" \
                "Automatic update failed for $HOST."
        fi


        exit 1
    fi
done
rm /tmp/nixos-dry-build.log
echo
echo "All hosts build successfully."

echo
echo "Running rebuild..."
exec /run/current-system/sw/bin/rebuild

if [[ -S "/run/user/$UID/bus" ]]; then
    sudo -u "$GIT_USER" \
        XDG_RUNTIME_DIR="/run/user/$UID" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$UID/bus" \
        notify-send \
        "NixOS Updated" \
        "Automatic update and rebuild completed successfully."
fi