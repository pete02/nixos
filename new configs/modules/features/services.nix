{self,inputs, ...}:{
  flake.nixosModules.services={lib,pkgs,config,...}:{
    options.services= {
      cleaner= lib.mkEnableOption "Enable the cleaner service";
      gitops= lib.mkEnableOption "Enable the gitops service";
    };
    config= lib.mkMerge[
      (lib.mkIf (config.services.cleaner){
        systemd.services.cleaner = {
          description = "Clean Downloads and Trash at shutdown";
          wantedBy = [ "multi-user.target" ];
          before = [ "shutdown.target" ]; # run at shutdown
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${pkgs.runtimeShell} -c 'rm -rf /home/pete/Downloads/* /home/pete/.local/share/Trash/*'";
          };
        };
      })
      (lib.mkIf (config.services.gitops) {
        systemd.services.gitops = {
          description = "Check remote NixOS config repo for updates";
          serviceConfig = {
            Type = "oneshot";
            Environment = "PATH=${pkgs.git}/bin:${pkgs.nixos-rebuild}/bin:/run/current-system/sw/bin";
            ExecStart = pkgs.writeShellScript "check-nixos-updates" (
              builtins.readFile "${self}/scripts/gitops.sh"
            );
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
      })
    ];
  };
}