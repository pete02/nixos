CONFIG_FOLDER=/etc/nixos

GIT_USER=$(stat -c '%U' "$CONFIG_FOLDER/.git")


echo "$GIT_USER"
if [[ -S "/run/user/$UID/bus" ]]; then
    sudo -u "$GIT_USER" \
        XDG_RUNTIME_DIR="/run/user/$UID" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$UID/bus" \
        notify-send \
        "NixOS Updated" \
        "Automatic update and rebuild completed successfully."
fi