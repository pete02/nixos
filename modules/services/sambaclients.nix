{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.services.routersamba;
in
{
  options.services.routersamba = {
    enable = lib.mkEnableOption "Enable router samba shares";

    shares = lib.mkOption {
      type = with lib.types; listOf attrs;
      default = [ ];
      description = ''
        List of SMB/CIFS shares to set up. Each mount should be an attribute set with:
          - path: mount point
          - device: SMB device string (e.g., //192.168.88.1/share)
          - options (optional): list of mount options
          - credentials (optional): path to credentials file
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.cifs-utils ];

    systemd.tmpfiles.rules = lib.concatMap (mount: [ "d ${mount.path} 0755 pete pete -" ]) cfg.shares;

    fileSystems = lib.attrsets.foldl' (
      acc: mount:
      acc
      // {
        ${mount.path} = {
          device = mount.device;
          fsType = "cifs";
          options =
            (mount.options or [
              "x-systemd.automount"
              "noauto"
              "x-systemd.idle-timeout=60"
              "x-systemd.device-timeout=5s"
              "x-systemd.mount-timeout=5s"
              "vers=3.0"
              "uid=1000"
              "gid=1000"
            ]
            )
            ++ lib.optionalString (mount.credentials != null) ("credentials=" + mount.credentials);
        };
      }
    ) { } cfg.shares;
  };
}
