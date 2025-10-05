{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
{
  options = {
    services.enable.gitops = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to enable autoupdater";
    };
  };
  config = mkIf config.services.enable.gitops {
    systemd.user.services.check-nixos-updates = {
      description = "Check remote NixOS config repo for updates";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "check-nixos-updates" ''
          set -e
          export GIT_SSH_COMMAND="ssh -i /etc/ssh/id_server -o IdentitiesOnly=yes" 
          cd /etc/nixos
          git fetch origin master
          LOCAL=$(git rev-parse @)
          REMOTE=$(git rev-parse @{u})
          BASE=$(git merge-base @ @{u})

          if [ "$LOCAL" != "$REMOTE" ]; then
            echo "Remote has updates, triggering autoupdater"
            systemctl --user start update-nixos-config.service
          else
            echo "Local in sync"
          fi
        '';
      };
    };


    systemd.timers.autoupdater = {
      description = "Timer for auto-updating NixOS from git";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "5m";
        OnUnitActiveSec = "1h";
        RandomizedDelaySec = "10m";
        Persistent = true;
      };
    };

  };
}
