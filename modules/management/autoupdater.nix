{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  updaterrcfg = config.services.autoupdater;
in
{
  options = {
    services.autoupdater.enable = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to enable autoupdater";
    };
  };
  config = mkIf updaterrcfg.enable {
    systemd.user.services.update-nixos-config = {
      description = "Auto-update NixOS config + flakes at boot";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "default.target" ];
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
          flaked=0
          pulled=0

          # Git pull as user
          echo "start fetching"
          if ! git pull --ff-only | grep -q "Already up to date"; then
            pulled=1
          fi
          echo "fetched from git"
          # Flake update as user
          nix flake update --update-input nixpkgs --update-input home-manager
          if ! git diff --quiet flake.lock; then
            git add flake.lock
            git commit -m "Auto-update flake inputs"
            git push origin master
            flaked=1
          fi

          if [ "$pulled" -eq 1 ] || [ "$flaked" -eq 1 ]; then
            msg="System ready for rebuild:"
            if [ "$pulled" -eq 1 ]; then
                msg="$msg \n- configuration pulled"
            fi
            if [ "$flaked" -eq 1 ]; then
                msg="$msg \n- flake updated"
            fi
            notify-send "NixOS" "$msg"
          fi
        ''}";
      };
    };
  };
}
