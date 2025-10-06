{
  pkgs,
  lib,
  config,
  ...
}:
{
  options.enable.routersamba = lib.mkEnableOption "enables router samba";

  config = lib.mkIf config.enable.routersamba {
    # For mount.cifs, required unless domain name resolution is not needed.
    environment.systemPackages = [ pkgs.cifs-utils ];
    fileSystems."/mnt/share" = {
      device = "//192.168.88.1/usb1-part1/pub/";
      fsType = "cifs";
      options =
        let
          # this line prevents hanging on network split
          automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";

        in
        [ "${automount_opts},credentials=/etc/nixos/smb-secrets" ];
    };
  };
}
