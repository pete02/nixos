{
  pkgs,
  lib,
  config,
  ...
}:
{
  options.smb = {
    enable = lib.mkEnableOption "enables samba client";
    router = lib.mkEnableOption "enables router samba";
    server = lib.mkEnableOption "enables router samba";
  };

  config = lib.mkIf config.smb.enable {
    # For mount.cifs, required unless domain name resolution is not needed.
    systemd.tmpfiles.rules = [
      "d /mnt/router 0755 pete pete -"
    ];
    environment.systemPackages = [ pkgs.cifs-utils ];
    fileSystems = {
      "/mnt/router" = lib.mkIf config.smb.router {
        device = "//192.168.88.1/home/";
        fsType = "cifs";
        options =
          let
            # this line prevents hanging on network split
            automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";
            creds = "credentials=/etc/smb/routersecret";
            vers = "vers=3.0";
            uidguid = "uid=1000,gid=1000";
          in
          [ "${automount_opts},${creds},${vers},${uidguid}" ];
      };

      "/mnt/server" = lib.mkIf config.smb.server {
        device = "//192.168.88.241/private/";
        fsType = "cifs";
        options =
          let
            # this line prevents hanging on network split
            automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";
            creds = "credentials=/etc/smb/serversecret";
            vers = "vers=3.0";
            uidguid = "uid=1000,gid=1000";
          in
          [ "${automount_opts},${creds},${vers},${uidguid}" ];
      };
    };
  };
}
