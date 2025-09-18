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

  systemd.services.update-nixos-config = {
    description = "Auto-update NixOS config + flakes at boot";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "update-nixos-config" ''
        set -e
        cd /etc/nixos
        changed=0
        if ! sudo -u pete git pull --ff-only | grep -q "Already up to date"; then
          changed=1
        fi

        sudo -u pete nix flake update
        if ! sudo -u pete git diff --quiet flake.lock; then
            sudo -u pete git add flake.lock
            sudo -u pete git commit -m "Auto-update flake inputs"
            sudo -u pete git push origin master
            changed=1
        fi

        if [ "$changed" -eq 1 ]; then
          nixos-rebuild switch --flake /etc/nixos#$(HOSTNAME)
          sudo -u pete DISPLAY=:0 \
            DBUS_SESSION_BUS_ADDRESS="unix:path=/run/userid -u pete)/bus" \
            notify-send "NixOS" "System configuration updated and rebuilt."
        fi
      '';
    };
  };
}
