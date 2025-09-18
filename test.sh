cd /etc/nixos
changed=0
if ! sudo -u pete HOME=/home/pete git pull --ff-only | grep -q "Already up to date"; then
  changed=1
fi

sudo -u pete nix flake update
if ! sudo -u HOME=/home/pete pete git diff --quiet flake.lock; then
    sudo -u pete HOME=/home/pete git add flake.lock
    sudo -u pete HOME=/home/pete git commit -m "Auto-update flake inputs"
    sudo -u pete HOME=/home/pete git push origin master
    changed=1
fi

if [ "$changed" -eq 1 ]; then
  nixos-rebuild switch --flake /etc/nixos#$(HOSTNAME)
  sudo -u pete DISPLAY=:0 \
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/userid -u pete)/bus" \
    notify-send "NixOS" "System configuration updated and rebuilt."
fi
