{
  lib,
  config,
  pkgs,
  ...
}:
{
  options = {
    enable.sync = lib.mkEnableOption "enables sync between desktops";
  };
  config = lib.mkIf config.enable.sync {
    environment.systemPackages = [ pkgs.rsync ];
    systemd.services.syncrestore = {
      description = "Restores desktop files.";
      after = [
        "network-online.target"
        "mnt-server.mount"
      ];
      wants = [
        "network-online.target"
        "mnt-server.mount"
      ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        User = config.username;
        Type = "oneshot";
        ExecStart = ''
          ${pkgs.bash}/bin/bash -c "
                    ${pkgs.rsync}/bin/rsync -au /mnt/server/desktopsync/code /home/pete/code
                    ${pkgs.rsync}/bin/rsync -au /mnt/server/desktopsync/vaults /home/pete/vaults
                  "
        '';
      };
    };

    systemd.services.sync = {
      description = "sync desktop files.";
      wantedBy = [ "multi-user.target" ];
      before = [ "shutdown.target" ];

      serviceConfig = {
        User = config.username;
        Type = "oneshot";
        ExecStart = ''
          ${pkgs.bash}/bin/bash -c "
                    [ -d /mnt/server/desktopsync ] || exit 0
                    ${pkgs.rsync}/bin/rsync -a --delete /home/pete/code /mnt/server/desktopsync/code
                    ${pkgs.rsync}/bin/rsync -a --delete /home/pete/vaults /mnt/server/desktopsync/vaults
                  "
        '';
      };
    };

  };
}
