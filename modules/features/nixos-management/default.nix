{self, inputs,...}:{
  flake.nixosModules.nixos-management={}:let 
    update=mkScript {
      name = "update";
      src = ./scripts/update.sh;

      runtimeInputs = with pkgs; [
        git
      ];

      substitutions = {
        REPOSITORY = "ssh://git@git.lumilukko.com:2222/Pete/nixos.git";
      };
    };
    gitops = mkScript {
      name = "gitops";
      src = ./scripts/gitops.sh;

      runtimeInputs = with pkgs; [
        curl
        git
      ];
    };

    rebuild = mkScript {
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
    options.nixos-management={
      auto-update=lib.mkEnableOption "Enables flake autoupdater";
    };
    config=lib.mkMerge [
      ({
        environment.systemPackages=[
          rebuild
        ];
      })
      (lib.mkIf config.nixos-management.auto-update {
        systemd.services.nixos-auto-update = {
          description = "Update flake inputs and rebuild NixOS";
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${update}/bin/update";
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

    ];
  };
}