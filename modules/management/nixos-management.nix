{
  pkgs,
  ...
}:
{
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nixpkgs.config.allowUnfree = true;

  nix.gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-older-than 10d";
  };

  nix.settings.auto-optimise-store = true;

  systemd.user.services.update-nixos-config = {
    description = "Auto-update NixOS config + flakes at boot";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.writeShellScript "sync-nixos-config" ''
        set -e
        echo "started git sync"
        until ping -c1 github.com >/dev/null 2>&1; do
          sleep 10
        done

        cd /etc/nixos
        changed=0

        # Git pull as user
        if ! pete git pull --ff-only | grep -q "Already up to date"; then
          changed=1
        fi

        # Flake update as user
        nix flake update
        if ! sudo -u pete git diff --quiet flake.lock; then
          git add flake.lock
          git commit -m "Auto-update flake inputs"
          push origin master
          changed=1
        fi

        if [ "$changed" -eq 1 ]; then
          sudo nixos-rebuild switch --flake /etc/nixos#$(hostname)
          DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u pete)/bus" \
            notify-send "NixOS" "System configuration updated and rebuilt."
        fi
        echo "ended git sync"
      ''}";
    };
  };
}
