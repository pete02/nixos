{
  self,
  inputs,
  system,
  ...
}: {
  flake.nixosModules.services = {
    lib,
    pkgs,
    config,
    system,
    ...
  }: {
    options.services = {
      cleaner = lib.mkEnableOption "Enable the cleaner service";
      gitops = lib.mkEnableOption "Enable the gitops service";
      autoUpdate = lib.mkEnableOption "Enables weekly automatic Nixos update and rebuild";
      gpucooler = lib.mkEnableOption "Enable the GPU cooler service";
      sync = lib.mkEnableOption "Enable syncing to server";
      mDNS = lib.mkEnableOption "Enable mDNS service for publishing IP to local network";
    };

    config = lib.mkMerge [
      (lib.mkIf (config.services.cleaner) {
        systemd.services.cleaner = {
          description = "Clean Downloads and Trash at shutdown";
          wantedBy = ["multi-user.target"];
          before = ["shutdown.target"]; # run at shutdown
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${pkgs.runtimeShell} -c 'rm -rf /home/pete/Downloads/* /home/pete/.local/share/Trash/*'";
          };
        };
      })


      (lib.mkIf config.services.sync {
        environment.systemPackages = [pkgs.rsync];
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
          wantedBy = ["multi-user.target"];

          serviceConfig = {
            User = config.username;
            Type = "oneshot";
            ExecStart = ''
              ${pkgs.rsync}/bin/rsync -au --info=progress2 /mnt/server/desktopsync/code /home/pete
            '';
          };
        };

        systemd.services.sync = {
          description = "sync desktop files.";
          wantedBy = ["multi-user.target"];
          before = ["shutdown.target"];

          serviceConfig = {
            User = config.username;
            Type = "oneshot";
            ExecStart = "${self.packages.${system}.sync}/bin/sync";
          };
        };
      })
     
    ];
  };
}
