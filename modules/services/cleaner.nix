{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cleanercfg = config.services.cleaner;
in
{
  options = {
    services.cleaner.enable = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to enable cleaner";
    };
  };
  config = mkIf cleanercfg.enable {
    systemd.services.cleaner = {
      description = "Clean Downloads and Trash at shutdown";
      After = "network.target";
      wantedBy = [
        "multi-user.target"
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "/bin/true";
        ExecStop = "${pkgs.runtimeShell} -c 'rm -rf /home/pete/Downloads/* /home/pete/.local/share/Trash/*'";
      };
    };
  };
}
