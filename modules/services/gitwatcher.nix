{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  gitopscfg = config.services.gitops;
in
{
  options = {
    services.gitops.enable = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to enable autoupdater";
    };
  };
  config = mkIf gitopscfg.enable {
    systemd.user.services.check-nixos-updates = {
      description = "Check remote NixOS config repo for updates";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "check-nixos-updates" ''
          set -e
          cd /etc/nixos
          git fetch origin master
          LOCAL=$(git rev-parse @)
          REMOTE=$(git rev-parse @{u})
          BASE=$(git merge-base @ @{u})

          if [ "$LOCAL" != "$REMOTE" ]; then
            echo "Remote has updates, triggering autoupdater"
            systemctl --user start update-nixos-config.service
          fi
        '';
      };
    };

  };
}
