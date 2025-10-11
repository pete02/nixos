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
        ExecStart = pkgs.writeShellScript "desktop-syncrestore" ''
          ${pkgs.rsync}/bin/rsync -au --info=progress2 /mnt/server/desktopsync/code /home/pete/code
          ${pkgs.rsync}/bin/rsync -au --info=progress2 /mnt/server/desktopsync/vaults /home/pete/vaults
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
        ExecStart = pkgs.writeShellScript "desktop-sync" ''
          [ -d /mnt/server/desktopsync ] || exit 0
          ${pkgs.rsync}/bin/rsync -a \
              --exclude 'node_modules/' \
              --exclude 'target/' \
              --exclude '.venv/' \
              --exclude '.nix-venv/' \
              --exclude '.mypy_cache/' \
              --exclude '.pytest_cache/' \
              --exclude '.git/' \
              --exclude '.cargo/' \
              --exclude '*.mp4' \
              --exclude 'dist/' \
              --info=progress2 \
          --delete /home/pete/code /mnt/server/desktopsync
          ${pkgs.rsync}/bin/rsync -a \
              --exclude 'node_modules/' \
              --exclude 'target/' \
              --exclude '.venv/' \
              --exclude '.nix-venv/' \
              --exclude '.mypy_cache/' \
              --exclude '.pytest_cache/' \
              --exclude '.git/' \
              --exclude '.cargo/' \
              --exclude 'dist/' \
              --info=progress2 \
           --delete /home/pete/vaults /mnt/server/desktopsync
        '';
      };
    };

  };
}
