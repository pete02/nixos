{
  self,
  inputs,
  system,
  ...
}: {
  flake.nixosModules.services = {
    lib,
    pkgs,
    config,
    system,
    ...
  }: {
    options.services = {
      cleaner = lib.mkEnableOption "Enable the cleaner service";
      gitops = lib.mkEnableOption "Enable the gitops service";
      autoUpdate = lib.mkEnableOption "Enables weekly automatic Nixos update and rebuild";
      gpucooler = lib.mkEnableOption "Enable the GPU cooler service";
      sync = lib.mkEnableOption "Enable syncing to server";
      sambaClient = lib.mkEnableOption "enables router samba";
      mDNS = lib.mkEnableOption "Enable mDNS service for publishing IP to local network";
      sambaServer = lib.mkEnableOption "enables samba server";
      bitwarden-backup = {
        enable = lib.mkEnableOption "Bitwarden backup to Google Drive";

        dataDir = lib.mkOption {
          type = lib.types.str;
          example = "/var/lib/bitwarden";
          description = "Bitwarden data folder to back up.";
        };

        containerName = lib.mkOption {
          type = lib.types.str;
          default = "bitwarden";
          description = "Docker container to stop/start (used when systemdUnit is null).";
        };

        systemdUnit = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "docker-bitwarden.service";
          description = ''
            Set this if the container is managed by systemd (e.g. virtualisation.oci-containers).
            Stopping through systemd stops the unit from restarting the container mid-backup.
          '';
        };

        remote = lib.mkOption {
          type = lib.types.str;
          default = "gdrive:bitwarden-backups";
          description = "rclone destination as remote:folder. The part before the colon names the remote.";
        };

        rcloneConfigFile = lib.mkOption {
          type = lib.types.path;
          description = ''
            Path to the SOPS-managed rclone configuration file.
            The decrypted file must remain outside the Nix store.
          '';
        };

        keep = lib.mkOption {
          type = lib.types.ints.positive;
          default = 5;
          description = "Number of most recent backups to keep.";
        };

        ntfyUrl = lib.mkOption {
          type = lib.types.str;
          default = "https://ntfy.lumilukko.com/Raysha";
          description = "ntfy URL for backup failure notifications.";
        };

        schedule = lib.mkOption {
          type = lib.types.str;
          default = "03:00";
          description = "systemd OnCalendar expression for when to run.";
        };
      };
    };

    config = lib.mkMerge [
      (lib.mkIf (config.services.cleaner) {
        systemd.services.cleaner = {
          description = "Clean Downloads and Trash at shutdown";
          wantedBy = ["multi-user.target"];
          before = ["shutdown.target"]; # run at shutdown
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${pkgs.runtimeShell} -c 'rm -rf /home/pete/Downloads/* /home/pete/.local/share/Trash/*'";
          };
        };
      })

      (lib.mkIf (config.services.gitops) {
        systemd.services.gitops = {
          description = "Check remote NixOS config repo for updates";
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${self.packages.${system}.gitops}/bin/gitops";
          };
        };

        systemd.timers.gitops = {
          description = "Timer for auto-updating NixOS from git";
          wantedBy = ["timers.target"];
          timerConfig = {
            OnBootSec = "5m";
            OnUnitActiveSec = "1h";
            RandomizedDelaySec = "10m";
            Persistent = true;
          };
        };
      })

      (lib.mkIf (config.services.mDNS) {
        services.avahi = {
          enable = true;
          nssmdns4 = true;
          publish = {
            addresses = true;
            enable = true;
          };
        };
      })

      (lib.mkIf config.services.autoUpdate {
        systemd.services.nixos-auto-update = {
          description = "Update flake inputs and rebuild NixOS";
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${self.packages.${system}.update}/bin/update";
          };
        };

        systemd.timers.nixos-auto-update = {
          description = "Weekly automatic NixOS update";
          wantedBy = ["timers.target"];
          after = ["network-online.target"];
          wants = ["network-online.target"];
          timerConfig = {
            OnBootSec = "15m";
            OnCalendar = "weekly";
            RandomizedDelaySec = "1h";
            Persistent = true;
          };
        };
      })

      (lib.mkIf (config.services.gpucooler) {
        systemd.services.gpu-fan-control = {
          description = "GPU Fan Control Service";
          wantedBy = ["multi-user.target"];
          after = ["multi-user.target"];

          serviceConfig = {
            ExecStart = "${self.packages.${system}.gpu-cooler}/bin/gpu-cooler";
            Restart = "always";
            RestartSec = 1;
          };
        };
      })

      (lib.mkIf config.services.sync {
        environment.systemPackages = [pkgs.rsync];
        systemd.services.syncrestore = {
          description = "Restores desktop files.";
          after = [
            "network-online.target"
            "mnt-server.mount"
          ];
          wants = [
            "network-online.target"
            "mnt-server.mount"
          ];
          wantedBy = ["multi-user.target"];

          serviceConfig = {
            User = config.username;
            Type = "oneshot";
            ExecStart = ''
              ${pkgs.rsync}/bin/rsync -au --info=progress2 /mnt/server/desktopsync/code /home/pete
            '';
          };
        };

        systemd.services.sync = {
          description = "sync desktop files.";
          wantedBy = ["multi-user.target"];
          before = ["shutdown.target"];

          serviceConfig = {
            User = config.username;
            Type = "oneshot";
            ExecStart = "${self.packages.${system}.sync}/bin/sync";
          };
        };
      })

      (lib.mkIf config.services.sambaClient {
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

      (lib.mkIf config.services.sambaServer {
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
      
      (lib.mkIf config.services.bitwarden-backup.enable {
        systemd.services.bitwarden-backup = {
          environment = {
            DATA_DIR = config.services.bitwarden-backup.dataDir;
            CONTAINER_NAME = config.services.bitwarden-backup.containerName; 
            RCLONE_REMOTE = config.services.bitwarden-backup.remote;
            KEEP = toString config.services.bitwarden-backup.keep;
            RCLONE_CONFIG = config.services.bitwarden-backup.rcloneConfigFile;
            NTFY_URL = config.services.bitwarden-backup.ntfyUrl;
          };
          after = ["network-online.target"];
          wants = ["network-online.target"];

          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${self.packages.x86_64-linux.bitwardenBackup}/bin/bitwarden_backup";
          };

          startAt = config.services.bitwarden-backup.schedule;
        };
      })
    ];
  };
}
