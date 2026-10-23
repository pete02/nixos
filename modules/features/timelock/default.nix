{self, ...}: {
  perSystem = {pkgs, ...}: {
    packages.timelock = self.lib.mkScript pkgs {
      name = "timelock";
      src = ./timelock.sh;
      runtimeInputs = with pkgs; [coreutils util-linux systemd];
    };
  };

  flake.nixosModules.timelock = {
    config,
    lib,
    pkgs,
    ...
  }: let
    inherit
      (lib)
      mkEnableOption
      mkIf
      mkOption
      types
      mapAttrs'
      nameValuePair
      ;

    cfg = config.services.timelock;

    controller = self.packages.${pkgs.stdenv.hostPlatform.system}.timelock;

    mkResourceWrapper = name: resource:
      pkgs.writeShellScriptBin "timelock-${name}" ''
        export TIMELOCK_STATE_DIR=${lib.escapeShellArg cfg.stateDir}
        export TIMELOCK_STATE_USER=${lib.escapeShellArg cfg.stateUser}

        export TIMELOCK_MAX_SESSION_SECS=${toString cfg.maxSessionSecs}
        export TIMELOCK_COOLDOWN_SECS=${toString cfg.cooldownSecs}
        export TIMELOCK_CUTOFF_HOUR=${toString cfg.cutoffHour}
        export TIMELOCK_LOCK_COMMAND=${lib.escapeShellArg (toString resource.lockCommand)}
        export TIMELOCK_UNLOCK_COMMAND=${lib.escapeShellArg (toString resource.unlockCommand)}

        exec ${controller}/bin/timelock \
          ${lib.escapeShellArg name} "$@"
      '';

    resourceWrappers = lib.mapAttrs mkResourceWrapper cfg.resources;
  in {
    options.services.timelock = {
      enable = mkEnableOption "generic resource timelock and expiry enforcement";

      stateDir = mkOption {
        type = types.str;
        default = "/var/lib/timelock";
        description = "Directory for persistent timelock state.";
      };

      stateUser = mkOption {
        type = types.str;
        default = "${config.username}";
        description = "User for persistent timelock state.";
      };

      maxSessionSecs = mkOption {
        type = types.ints.positive;
        default = 3600;
        description = "Maximum unlocked session duration, in seconds.";
      };

      cooldownSecs = mkOption {
        type = types.ints.between 0 2147483647;
        default = 72 * 60 * 60;
        description = "Required locked duration before unlocking, in seconds.";
      };

      cutoffHour = mkOption {
        type = types.ints.between 0 23;
        default = 21;
        description = "Local hour after which unlocking is prohibited.";
      };

      checkInterval = mkOption {
        type = types.str;
        default = "15s";
        description = "Interval between automatic expiry enforcement runs.";
      };

      resources = mkOption {
        default = {};
        description = ''
          Resources controlled by timelock. Each resource must provide
          executable lockCommand and unlockCommand paths.
        '';

        type = types.attrsOf (types.submodule {
          options = {
            lockCommand = mkOption {
              type = types.str;
              description = "Executable invoked to lock this resource.";
            };

            unlockCommand = mkOption {
              type = types.str;
              description = "Executable invoked to unlock this resource.";
            };
          };
        });
      };
    };

    config = mkIf cfg.enable {
      environment.systemPackages = [
        controller
      ];

      systemd.tmpfiles.rules = [
        "d ${cfg.stateDir} 0750 root root - -"
      ];

      systemd.services =
        mapAttrs' (
          name: _:
            nameValuePair "timelock-${name}-expiry" {
              description = "Enforce timelock expiry for ${name}";

              serviceConfig = {
                Type = "oneshot";
                ExecStart = "${resourceWrappers.${name}}/bin/timelock-${name} expire";
                User = "root";
                UMask = "0077";
              };
            }
        )
        cfg.resources;

      systemd.timers =
        mapAttrs' (
          name: _:
            nameValuePair "timelock-${name}-expiry" {
              description = "Periodic expiry enforcement for ${name}";

              wantedBy = ["timers.target"];

              timerConfig = {
                OnBootSec = "15s";
                OnUnitActiveSec = cfg.checkInterval;
                Persistent = true;
                Unit = "timelock-${name}-expiry.service";
              };
            }
        )
        cfg.resources;
    };
  };
}
