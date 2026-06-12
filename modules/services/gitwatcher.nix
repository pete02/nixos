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
    systemd.services.gitops = {
      description = "Check remote NixOS config repo for updates";
      serviceConfig = {
        Type = "oneshot";
        Environment = "PATH=${pkgs.git}/bin:${pkgs.nixos-rebuild}/bin:/run/current-system/sw/bin";
        ExecStart = pkgs.writeShellScript "check-nixos-updates" ''
          set -e
          TIMESTAMP_FILE="/var/lib/gitops/last-sync"
          mkdir -p /var/lib/gitops

          export GIT_SSH_COMMAND="ssh -i /etc/ssh/id_server -o IdentitiesOnly=yes"
          cd /etc/nixos
          git fetch origin master
          LOCAL=$(git rev-parse @)
          REMOTE=$(git rev-parse @{u})

          if [ "$LOCAL" != "$REMOTE" ]; then
            echo "Remote has updates, triggering autoupdater"
            git reset --hard origin/master
            git pull
            nixos-rebuild switch --flake /etc/nixos#$HOSTNAME || echo "Rebuild had warnings/errors, continuing anyway"
            date -Iseconds > "$TIMESTAMP_FILE"

            if [ "$(readlink /run/booted-system/kernel)" != "$(readlink /run/current-system/kernel)" ] || \
              [ "$(readlink /run/booted-system/initrd)" != "$(readlink /run/current-system/initrd)" ]; then
              echo "Kernel or initrd changed, scheduling reboot for 03:00..."
              systemd-run --on-calendar="03:00" systemctl reboot
            fi
          else
            if [ -f "$TIMESTAMP_FILE" ]; then
              echo "Local in sync (last build: $(cat $TIMESTAMP_FILE))"
            else
              echo "Local in sync (no previous timestamp found)"
            fi
          fi
        '';
      };
    };

    systemd.timers.gitops = {
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
