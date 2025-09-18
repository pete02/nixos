cd /etc/nixos
changed=0

if ! git pull --ff-only | grep -q "Already up to date"; then
  changed=1
fi

nix flake update
if ! git diff --quiet flake.lock; then
  changed=1
fi

if [ "$changed" -eq 1 ]; then
  nixos-rebuild switch --flake /etc/nixos#$(HOSTNAME)
  sudo -u pete DISPLAY=:0 \
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u pete)/bus" \
    ${pkgs.libnotify}/bin/notify-send "NixOS" "System configuration updated and rebuilt."
fi
