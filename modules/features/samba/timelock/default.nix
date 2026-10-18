{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.samba-timelock = {
    lib,
    pkgs,
    config,
    ...
  }: let
    cfg = config.samba.timelock;

    timelockPackage = self.packages.${pkgs.system}.timelock;

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

    # Samba's authorization hook delegates policy to the generic controller.
    # The no-op commands are intentional: Samba enforces access at connection time.
    samba-noop = pkgs.writeShellApplication {
      name = "samba-timelock-noop";
      runtimeInputs = [];

      text = ''
        if [[ "''${1:-}" == "--check" ]]; then
          exit 0
        fi

        if [[ $# -ne 0 ]]; then
          echo "Usage: samba-timelock-noop [--check]" >&2
          exit 2
        fi

        exit 0
      '';
    };

    preexec = self.lib.mkScript pkgs {
      name = "preexec";
      src = ./scripts/preexec.sh;

      runtimeInputs = with pkgs; [
        coreutils
        util-linux
        logger
        timelockPackage
      ];

      substitutions = {
        STATE_DIR = "/var/lib/timelock";
        MAX_SESSION_SECS = toString (cfg.maxSessionMinutes * 60);
        COOLDOWN_SECS = toString (cfg.cooldownHours * 60 * 60);
        CUTOFF_HOUR = toString cfg.cutoffHour;
        NOOP_COMMAND = "${samba-noop}/bin/samba-timelock-noop";
      };
    };
  in {
    options.samba.timelock = {
      server = lib.mkEnableOption "Samba timelock server";
      client = lib.mkEnableOption "Samba timelock client";

      cooldownHours = lib.mkOption {
        type = lib.types.ints.positive;
        default = 72;
        description = ''
          Cooldown period in hours before access can be granted again.
        '';
      };

      cutoffHour = lib.mkOption {
        type = lib.types.ints.between 0 23;
        default = 23;
        description = ''
          Local hour (0-23) after which new sessions cannot be unlocked.
        '';
      };

      maxSessionMinutes = lib.mkOption {
        type = lib.types.ints.positive;
        default = 90;
        description = ''
          Maximum session duration in minutes before automatic locking.
        '';
      };
    };

    config = lib.mkMerge [
      (lib.mkIf cfg.server {
        environment.systemPackages = [
          alanna-filter
          raysha-filter
          preexec
        ];

        sops.secrets."samba/timelock" = {};
        sops.secrets."agh" = {};

        services.timelock = {
          enable = true;

          stateDir = "/var/lib/timelock";
          maxSessionSecs = cfg.maxSessionMinutes * 60;
          cooldownSecs = cfg.cooldownHours * 60 * 60;
          cutoffHour = cfg.cutoffHour;
          checkInterval = "15s";

          resources.samba = {
            lockCommand = "${samba-noop}/bin/samba-timelock-noop";
            unlockCommand = "${samba-noop}/bin/samba-timelock-noop";
          };
        };

        services.samba = {
          enable = true;
          openFirewall = true;

          settings = {
            global = {
              security = "user";
              workgroup = "WORKGROUP";
            };

            timelock = {
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
            };
          };
        };

        systemd.services.credentials = {
          description = "Set Samba password for timelock share from SOPS secret";
          wantedBy = ["multi-user.target"];
          after = ["samba.service"];

          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };

          script = ''
            username=$(grep '^username=' /run/secrets/samba/timelock | cut -d= -f2)
            password=$(grep '^password=' /run/secrets/samba/timelock | cut -d= -f2)
            printf '%s\n%s\n' "$password" "$password" \
              | ${pkgs.samba}/bin/smbpasswd -a -s "$username"
          '';
        };
      })

      (lib.mkIf cfg.client {
        systemd.tmpfiles.rules = [
          "d /mnt/timelock 0755 ${config.username} ${config.username} -"
        ];

        environment.systemPackages = [
          pkgs.cifs-utils
        ];

        sops.secrets."samba/timelock" = {};

        fileSystems."/mnt/timelock" = {
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
      })
    ];
  };
}
