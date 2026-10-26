{self, ...}: {
  flake.nixosModules.samba-timelock = {
    lib,
    pkgs,
    config,
    ...
  }: let
    cfg = config.samba.timelock;


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
      ];
      substitutions = {
        TIMELOCK = "${config.services.timelock.resourcePackages.samba}/bin/timelock-samba";
      };
    };
  in {
    options.samba.timelock = {
      enable = lib.mkEnableOption "Samba timelock server";

      cooldownHours = lib.mkOption {
        type = lib.types.ints.positive;
        default = 72;
        description = "Cooldown period in hours before access can be granted again.";
      };

      cutoffHour = lib.mkOption {
        type = lib.types.ints.between 0 23;
        default = 23;
        description = "Local hour (0-23) after which new sessions cannot be unlocked.";
      };

      maxSessionMinutes = lib.mkOption {
        type = lib.types.ints.positive;
        default = 90;
        description = "Maximum session duration in minutes.";
      };
    };

    config = lib.mkMerge [
      (lib.mkIf cfg.enable {
        environment.systemPackages = [
          alanna-filter
          raysha-filter
          preexec
          config.services.timelock.resourcePackages.samba
        ];
        sops.secrets."agh" = {};

        samba.servers.timelock = {
          enable = true;
          credentialsSecret = "samba/timelock";

          shares.timelock = {
            path = "/mnt/timelock";
            rootPreexec = "${preexec}/bin/preexec";
            rootPreexecClose = true;
          };
        };

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
      })
    ];
  };
}
