# Determine Pete's runtime directory
USER="pete"
XDG_RUNTIME_DIR="/run/user/$(id -u $USER)"
export XDG_RUNTIME_DIR

# Run dunstctl in the user's session
if command -v dunstctl &> /dev/null; then
    DBUS_SESSION_BUS_ADDRESS=unix:path=$XDG_RUNTIME_DIR/bus dunstctl close-all \
        || echo "Warning: failed to clear notifications"
fi
