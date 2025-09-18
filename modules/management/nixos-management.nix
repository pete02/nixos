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
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      Environment = ''
        PATH=/run/current-system/sw/bin:/run/current-system/profile/bin:/usr/bin:/bin
      '';
      ExecStart = "${pkgs.writeShellScript "update-nixos-config" ''
        set -ex
        until ping -c1 github.com >/dev/null 2>&1; do
          sleep 10
        done

        cd /etc/nixos
        changed=0

        # Git pull as user
        echo "start fetching"
        if ! git pull --ff-only | grep -q "Already up to date"; then
          changed=1
        fi
        echo "fetched from git"
        # Flake update as user
        nix flake update
        if ! git diff --quiet flake.lock; then
          git add flake.lock
          git commit -m "Auto-update flake inputs"
          git push origin master
          changed=1
        fi

        if [ "$changed" -eq 1 ]; then
          sudo nixos-rebuild switch --flake /etc/nixos#$(hostname)
          notify-send "NixOS" "System configuration updated and rebuilt."
        fi
      ''}";
    };
  };
}
