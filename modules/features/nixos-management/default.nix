{self, ...}: {
  flake.nixosModules.nixos-management = {
    lib,
    pkgs,
    config,
    ...
  }: let
    update = self.lib.mkScript pkgs {
      name = "update";
      src = ./scripts/update.sh;

      runtimeInputs = with pkgs; [
        git
      ];

      substitutions = {
        REPOSITORY = "ssh://git@git.lumilukko.com:2222/pete/nixos.git";
      };
    };
    gitops = self.lib.mkScript pkgs {
      name = "gitops";
      src = ./scripts/gitops.sh;

      runtimeInputs = with pkgs; [
        curl
        openssh
        git
        coreutils
      ];
      substitutions = {
        NTFY_SUCCESS_URL = config.nixos-management.gitops.ntfyUpgrade;
        NTFY_FAILURE_URL = config.nixos-management.gitops.ntfyFailure;
      };
    };

    rebuild = self.lib.mkScript pkgs {
      name = "rebuild";
      src = ./scripts/rebuild.sh;
      runtimeInputs = with pkgs; [
        coreutils
        findutils
        git
        gnugrep
        inetutils
        nixos-rebuild
        nvd
      ];
    };
  in {
    options.nixos-management = {
      auto-update = lib.mkEnableOption "Enables flake autoupdater";
      gitops = {
        enable = lib.mkEnableOption "Enables nixos-gitops";
        ntfyFailure = lib.mkOption {
          type = lib.types.str;
          default = self.lib.fleet.ntfyFailure config.hostname;
          description = "ntfy URL for backup failure notifications.";
        };
        ntfyUpgrade = lib.mkOption {
          type = lib.types.str;
          default = self.lib.fleet.ntfyUpgrade config.hostname;
          description = "ntfy URL for backup failure notifications.";
        };
      };
    };
    config = lib.mkMerge [
      {
        environment.systemPackages = [
          rebuild
        ];
      }

      (lib.mkIf config.nixos-management.auto-update {
        systemd.services.nixos-auto-update = {
          description = "Update flake inputs and rebuild NixOS";
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${update}/bin/update";
          };
        };

        systemd.timers.nixos-auto-update = {
          description = "Daily automatic NixOS update at 03:00";
          wantedBy = ["timers.target"];
          after = ["network-online.target"];
          wants = ["network-online.target"];
          timerConfig = {
            OnBootSec = "15m";
            OnCalendar = "03:00";
            RandomizedDelaySec = "1h";
            Persistent = true;
          };
        };
      })

      (lib.mkIf config.nixos-management.gitops.enable {
        systemd.services.gitops = {
          description = "Check remote NixOS config repo for updates";
          restartIfChanged = false;
          stopIfChanged = false;
          environment = {
            GIT_CONFIG_COUNT = "1";
            GIT_CONFIG_KEY_0 = "safe.directory";
            GIT_CONFIG_VALUE_0 = "/etc/nixos";
          };
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${gitops}/bin/gitops";
          };
        };

        systemd.timers.gitops = {
          description = "Daily GitOps check and startup update";
          wantedBy = ["timers.target"];
          timerConfig = {
            OnBootSec = "5m";
            OnCalendar = "daily";
            RandomizedDelaySec = "10m";
            Persistent = true;
          };
        };
      })
    ];
  };
}
