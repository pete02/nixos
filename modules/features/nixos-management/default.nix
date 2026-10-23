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
        git
      ];
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
      gitops = lib.mkEnableOption "Enables nixos-gitops";
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

      (lib.mkIf config.nixos-management.gitops {
        systemd.services.gitops = {
          description = "Check remote NixOS config repo for updates";
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
