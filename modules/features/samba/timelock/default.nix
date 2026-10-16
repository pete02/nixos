{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.timelock = {
    lib,
    pkgs,
    config,
    ...
  }: let
    cfg = config.sambaTimelock;
    raysha-filter = self.lib.mkScript pkgs {
      name = "raysha-filter";
      src = ./scripts/agh-filter.sh;

      runtimeInputs = with pkgs; [
        curl
        jq
        logger
        glibc.getent
        gawk
      ];

      substitutions = {
        CLIENT_NAME = "raysha.local";
        CLIENT_MAC = "88:d8:2e:ba:62:29";
      };
    };

    alanna-filter = self.lib.mkScript pkgs {
      name = "alanna-filter";
      src = ./scripts/agh-filter.sh;

      runtimeInputs = with pkgs; [
        curl
        jq
        logger
        glibc.getent
        gawk
      ];

      substitutions = {
        CLIENT_NAME = "alanna.local";
        CLIENT_MAC = "2C:CF:67:DA:15:86";
      };
    };
    preexec = self.lib.mkScript pkgs {
      name = "preexec";
      src = ./scripts/preexec.sh;

      runtimeInputs = with pkgs; [
        coreutils
        logger
        raysha-filter
        alanna-filter
      ];

      substitutions = {
        STATE_DIR = "/var/lib/samba-timelock";
        COOLDOWN_SECS = "${toString (72 * 60 * 60)}";
        CUTOFF_HOUR = "${toString 23}";
      };
    };

    postexec = self.lib.mkScript pkgs {
      name = "postexec";
      src = ./scripts/postexec.sh;

      runtimeInputs = with pkgs; [
        samba
        logger
        coreutils
        raysha-filter
        alanna-filter
      ];

      substitutions = {
        STATE_DIR = "/var/lib/samba-timelock";
        SHARE_NAME = "timelock";
      };
    };

    enforce = self.lib.mkScript pkgs {
      name = "enforce";
      src = ./scripts/enforce.sh;

      runtimeInputs = with pkgs; [
        samba
        logger
        coreutils
        raysha-filter
        alanna-filter
      ];

      substitutions = {
        STATE_DIR = "/var/lib/samba-timelock";
        SHARE_NAME = "timelock";
        MAX_SESSION_SECS = "${toString (90 * 60)}";
        CUTOFF_HOUR = "${toString 23}";
      };
    };
  in {
    options.sambaTimelock = {
      server = lib.mkEnableOption "enables timelock server";
      client = lib.mkEnableOption "enables timelock server";
    };

    config = lib.mkMerge [
      (lib.mkIf (cfg.server) {
        environment.systemPackages = [
          alanna-filter
          raysha-filter
        ];

        sops.secrets."samba/timelock" = {};
        sops.secrets."agh" = {};

        users.users.timelock = {
          isSystemUser = true;
          group = "nogroup";
        };

        systemd.tmpfiles.rules = [
          "d /var/lib/samba-timelock 0750 root root -"
        ];

        services.samba = {
          enable = true;
          openFirewall = true;
          settings = {
            global = {
              security = "user";
              "workgroup" = "WORKGROUP";
            };
            "timelock" = {
              path = "/mnt/timelock";
              browseable = "yes";
              "read only" = "no";
              "guest ok" = "no";
              "create mask" = "0644";
              "directory mask" = "0755";
              "force user" = config.username;
              "force group" = "users";

              "root preexec" = "${preexec}/bin/preexec";
              "root preexec close" = "yes";
              "root postexec" = "${postexec}/bin/postexec";
            };
          };
        };

        systemd.services.credentials = {
          description = "Set Samba password for timelock share from sops secret";
          wantedBy = ["multi-user.target"];
          after = ["samba.service"];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = ''
            username=$(grep '^username=' /run/secrets/samba/timelock | cut -d= -f2)
            password=$(grep '^password=' /run/secrets/samba/timelock | cut -d= -f2)
            echo -e "$password\n$password" | ${pkgs.samba}/bin/smbpasswd -a -s "$username"
          '';
        };

        systemd.services.enforce = {
          description = "Enforce samba timelock session limits";
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${enforce}/bin/enforce";
          };
        };

        systemd.timers.enforce = {
          description = "Periodic check for samba timelock enforcement";
          wantedBy = ["timers.target"];
          timerConfig = {
            OnBootSec = "1m";
            OnUnitActiveSec = "30s";
            AccuracySec = "5s";
          };
        };
      })

      (lib.mkIf (cfg.client) {
        systemd.tmpfiles.rules = [
          "d /mnt/timelock 0755 pete pete -"
        ];
        environment.systemPackages = [pkgs.cifs-utils];
        sops.secrets."samba/timelock" = {};

        fileSystems = {
          "/mnt/timelock" = {
            device = "//aria.local/timelock/";
            fsType = "cifs";
            options = [
              "noauto"
              "user"
              "x-systemd.device-timeout=5s"
              "x-systemd.mount-timeout=5s"
              "credentials=/run/secrets/samba/timelock"
              "vers=3.0"
              "uid=1000"
              "gid=1000"
            ];
          };
        };
      })
    ];
  };
}
