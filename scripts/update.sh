#!/usr/bin/env bash
set -euo pipefail

CONFIG_FOLDER="@CONFIG_FOLDER@"

check() {
    echo "Checking git..."
    command -v git >/dev/null || return 1

    echo "Checking nixos-rebuild..."
    command -v nixos-rebuild >/dev/null || return 1

    echo "Checking treefmt..."
    command -v treefmt >/dev/null || return 1

    echo "Checking sudo..."
    command -v sudo >/dev/null || return 1

    echo "Checking stat..."
    command -v stat >/dev/null || return 1

    echo "Checking find..."
    command -v find >/dev/null || return 1

    echo "Checking sort..."
    command -v sort >/dev/null || return 1

    echo "Checking rm..."
    command -v rm >/dev/null || return 1

    echo "Checking notify-send..."
    command -v notify-send >/dev/null || return 1

    echo "All dependencies available."
}

if [[ "${1:-}" == "--check" ]]; then
    check
    exit $?
fi


[[ -d "${CONFIG_FOLDER}" ]] || {
    echo "ERROR: CONFIG_FOLDER does not exist: ${CONFIG_FOLDER}" >&2
    exit 1
}

[[ -d "${CONFIG_FOLDER}/.git" ]] || {
    echo "ERROR: ${CONFIG_FOLDER} is not a Git repository." >&2
    exit 1
}

[[ -d "${CONFIG_FOLDER}/modules/hosts" ]] || {
    echo "ERROR: Host configuration directory missing." >&2
    exit 1
}

[[ -x /run/current-system/sw/bin/rebuild ]] || {
    echo "ERROR: rebuild command not found." >&2
    exit 1
}

git_cmd() {
    if [[ $EUID -eq 0 ]]; then
        sudo -H -u "$GIT_USER" git "$@"
    else
        git "$@"
    fi
}



GIT_USER=$(stat -c '%U' "$CONFIG_FOLDER/.git")
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