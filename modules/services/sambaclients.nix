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
    systemd.tmpfiles.rules = [
      "d /mnt/router 0755 root root -"
    ];
    environment.systemPackages = [ pkgs.cifs-utils ];
    fileSystems."/mnt/router" = {
      device = "//192.168.88.1/home/";
      fsType = "cifs";
      options =
        let
          # this line prevents hanging on network split
          automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";
          creds = "credentials=/etc/smb/smb-secrets";
          vers = "vers=3.0";
        in
        [ "${automount_opts},${creds},${vers}" ];
    };
  };
}
