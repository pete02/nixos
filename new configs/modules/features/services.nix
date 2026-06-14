{self,inputs, ...}:{
  flake.nixosModules.services={lib,pkgs,...}:{
    options.services= {
      cleaner= lib.mkEnableOption "Enable the cleaner service"
    };
    config= lib.mkMerge[
      (lib.mkIf (options.services.cleaner){
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
    ]
  }
}