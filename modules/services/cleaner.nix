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
      before = [
        "halt.target"
        "reboot.target"
        "shutdown.target"
      ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.runtimeShell} -c 'rm -rf /home/pete/Downloads/* /home/pete/.local/share/Trash/*'";
      };
    };
  };
}
