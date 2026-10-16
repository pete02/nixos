{self,inputs,...}:
{
  flake.nixosModules.samba={
    lib,config,pkgs,...
  }:{
    options.samba={
      server= lib.mkEnableOption "enables timelock server";
      client= lib.mkEnableOption "enables timelock server";
    };
    config=lib.mkMerge [
      (lib.mkIf config.samba.client {
        systemd.tmpfiles.rules = [
          "d /mnt/router 0755 pete pete -"
        ];
        environment.systemPackages = [pkgs.cifs-utils];
        sops.secrets."samba/server" = {};

        fileSystems = {
          "/mnt/server" = {
            device = "//aria.local/server/";
            fsType = "cifs";
            options = let
              # this line prevents hanging on network split
              automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";
              creds = "credentials=/run/secrets/samba/server";
              vers = "vers=3.0";
              uidguid = "uid=1000,gid=1000";
            in ["${automount_opts},${creds},${vers},${uidguid}"];
          };
        };
      })

      (lib.mkIf config.samba.server {
        sops.secrets."samba/server" = {};
        services.samba = {
          enable = true;
          openFirewall = true;
          settings = {
            global = {
              security = "user";
              "workgroup" = "WORKGROUP";
              "server string" = "smbnix";
              "netbios name" = "smbnix";
              "hosts allow" = "192.168.88.0/24 10.0.0.0/24 127.0.0.1 localhost";
              "hosts deny" = "0.0.0.0/0";
              "guest account" = "nobody";
              "map to guest" = "bad user";
            };
            "server" = {
              "path" = "/mnt/server";
              "browseable" = "yes";
              "read only" = "no";
              "guest ok" = "no";
              "create mask" = "0644";
              "directory mask" = "0755";
              "force user" = config.username;
              "force group" = "users";
            };
          };
        };

        systemd.services.samba-credentials = {
          description = "Set Samba password from sops secret";
          wantedBy = ["multi-user.target"];
          after = [
            "samba.service"
          ];
          requires = ["sops-nix.service"];

          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };

          script = ''
            # Parse credentials file
            username=$(grep '^username=' /run/secrets/samba/server | cut -d= -f2)
            password=$(grep '^password=' /run/secrets/samba/server | cut -d= -f2)

            # Set samba password
            echo -e "$password\n$password" | ${pkgs.samba}/bin/smbpasswd -a -s "$username"
          '';
        };
      })
    ];
  };
}