{
  config,
  lib,
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
      wantedBy = [
        "halt.target"
        "reboot.target"
        "shutdown.target"
      ];
      serviceConfig = {
        User = "pete";
        Type = "oneshot";
        ExecStart = "/usr/bin/rm -rf /home/pete/Downloads/* /home/pete/.local/share/Trash/*";
      };
    };
  };
}
