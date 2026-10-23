{self, ...}: {
  flake.nixosModules.healthcheck = {
    pkgs,
    config,
    lib,
    ...
  }: let
    health-check = self.lib.mkScript pkgs {
      name = "health_check";
      src = ./scripts/healthcheck.sh;
      runtimeInputs = with pkgs; [
        smartmontools
        memtester
        curl
        gnugrep
        coreutils
        gnused
      ];
    };
    mdadm-check = self.lib.mkScript pkgs {
      name = "mdadm-check";
      src = ./scripts/mdadm-check.sh;
      runtimeInputs = with pkgs; [
        curl
        coreutils
        gnused
      ];
      checkSetup = ''
        export SYS="$TMPDIR/sys"
        mkdir -p "$SYS/block"
      '';
    };
    bcachefs-check = self.lib.mkScript pkgs {
      name = "bcachefs-check";
      src = ./scripts/bcachefs-check.sh;
      runtimeInputs = with pkgs; [
        bcachefs-tools
        curl
        util-linux
        hostname
        gawk
        gnugrep
        coreutils
      ];
    };
  in {
    options.healthcheck = {
      enable = lib.mkEnableOption "scheduled disk and RAM health check";
      devices = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
      };
      memSize = lib.mkOption {
        type = lib.types.str;
        default = "100M";
      };
      ntfyUrl = lib.mkOption {
        type = lib.types.str;
        default = self.lib.fleet.ntfyTopic config.hostname;
        description = "ntfy topic URL. Empty string disables notifications.";
      };
      schedule = lib.mkOption {
        type = lib.types.str;
        default = "Sun 03:00";
      };
      mdadm = {
        enable = lib.mkEnableOption "MD RAID health check";
        devices = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          description = "MD RAID devices that must exist.";
        };
      };

      bcachefs = {
        enable = lib.mkEnableOption "bcachefs health check";
        uuid = lib.mkOption {
          type = lib.types.str;
          default = "";
        };
        devices = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          description = "bcachefs devices that must exist.";
        };
      };
    };

    config = lib.mkMerge [
      (lib.mkIf config.healthcheck.enable {
        systemd.services.health-check = {
          path = with pkgs; [smartmontools memtester curl gnugrep coreutils];
          environment = {
            DEVICES = lib.concatStringsSep " " config.healthcheck.devices;
            MEMSIZE = config.healthcheck.memSize;
            NTFY_URL = config.healthcheck.ntfyUrl;
          };
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${health-check}/bin/health_check";
            LogsDirectory = "health-check"; # /var/log/health-check, matches the script's default
          };
          startAt = config.healthcheck.schedule;
        };
      })

      (lib.mkIf config.healthcheck.mdadm.enable {
        assertions = [
          {
            assertion = config.healthcheck.ntfyUrl != "";
            message = "healthcheck.ntfyUrl must not be empty when healthcheck.mdadm.enable is true.";
          }
          {
            assertion = config.healthcheck.mdadm.devices != [];
            message = "healthcheck.mdadm.devices must not be empty when healthcheck.mdadm.enable is true.";
          }
        ];

        systemd.services.mdadm-check = {
          path = with pkgs; [curl coreutils gnused];
          environment = {
            EXPECT = lib.concatStringsSep " " config.healthcheck.mdadm.devices;
            NTFY_URL = config.healthcheck.ntfyUrl;
          };
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${mdadm-check}/bin/mdadm-check";
            LogsDirectory = "health-check";
          };
          startAt = "daily";
        };
      })

      (lib.mkIf config.healthcheck.bcachefs.enable {
        assertions = [
          {
            assertion = config.healthcheck.ntfyUrl != "";
            message = "healthcheck.ntfyUrl must not be empty when healthcheck.bcachefs.enable is true.";
          }
          {
            assertion = config.healthcheck.bcachefs.devices != [];
            message = "healthcheck.bcachefs.devices must not be empty when healthcheck.bcachefs.enable is true.";
          }
          {
            assertion = config.healthcheck.bcachefs.uuid != "";
            message = "healthcheck.bcachefs.uuid must not be empty when healthcheck.bcachefs.enable is true.";
          }
        ];

        systemd.services.bcachefs-check = {
          path = with pkgs; [
            curl
            coreutils
            util-linux
            gawk
            gnugrep
            bcachefs-tools
          ];

          environment = {
            EXPECTED_UUID = config.healthcheck.bcachefs.uuid;

            EXPECTED_DEVICES =
              lib.concatStringsSep " " config.healthcheck.bcachefs.devices;

            NTFY_URL = config.healthcheck.ntfyUrl;
          };

          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${bcachefs-check}/bin/bcachefs-check";
            LogsDirectory = "health-check";
          };

          startAt = "daily";
        };
      })
    ];
  };
}
