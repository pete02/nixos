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
      wantedBy = [ "multi-user.target" ];
      before = [ "shutdown.target" ]; # run at shutdown
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.runtimeShell} -c ''
      rm -rf /home/pete/Downloads/* \
             /home/pete/.local/share/Trash/* \
             /home/pete/.cache/thumbnails/* \
             /home/pete/.cache/vlc/* \
             /home/pete/.cache/mpv/* \
             /home/pete/.cache/pip
    ''";
      };
    };
  };
}
