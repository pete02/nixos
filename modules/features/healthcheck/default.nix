{self, inputs,...}:
{
  flake.nixosModules.healthcheck={
    pkgs, config, lib, ...
  }:let 
      healthCheck = mkScript {
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
      mdadmCheck = flake.lib.mkScript pkgs {
        name = "mdadm_check";
        src = ./scripts/mdadm_check.sh;
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
      bcachefsCheck = mkScript {
        name = "bcachefs_check";
        src = ./scripts/bcachefs_check.sh;
        runtimeInputs = with pkgs; [
          bcachefs-tools
          curl
          util-linux
          coreutils
        ];
      };
  in {
    options.health-check = {
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
          default = "";
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
          devices = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = "bcachefs devices that must exist.";
          };
        };
      };

      config=lib.mkMerge=[
        (lib.mkIf config.services.health-check.enable {
          systemd.services.health-check = {
            path = with pkgs; [smartmontools memtester curl gnugrep coreutils];
            environment = {
              DEVICES = lib.concatStringsSep " " config.services.health-check.devices;
              MEMSIZE = config.services.health-check.memSize;
              NTFY_URL = config.services.health-check.ntfyUrl;
            };
            serviceConfig = {
              Type = "oneshot";
              ExecStart = "${self.packages.x86_64-linux.healthCheck}/bin/health_check";
              LogsDirectory = "health-check"; # /var/log/health-check, matches the script's default
            };
            startAt = config.services.health-check.schedule;
          };
        })

        (lib.mkIf config.services.health-check.mdadm.enable {
          systemd.services.mdadm-check = {
            path = with pkgs; [curl coreutils gnused];
            environment = {
              EXPECT = lib.concatStringsSep " " config.services.health-check.mdadm.devices;
              NTFY_URL = config.services.health-check.ntfyUrl;
            };
            serviceConfig = {
              Type = "oneshot";
              ExecStart = "${self.packages.x86_64-linux.mdadmCheck}/bin/mdadm_check";
              LogsDirectory = "health-check";
            };
            startAt = "daily";
          };
        })

        (lib.mkIf config.services.health-check.bcachefs.enable {
          systemd.services.bcachefs-check = {
            environment = {
              EXPECT = lib.concatStringsSep " " config.services.health-check.bcachefs.devices;
              NTFY_URL = config.services.health-check.ntfyUrl;
            };

            serviceConfig = {
              Type = "oneshot";
              ExecStart = "${self.packages.x86_64-linux.bcachefsCheck}/bin/bcachefs_check";
              LogsDirectory = "health-check";
            };

            startAt = "daily";
          };
        })
      ];
  };
}