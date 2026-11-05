{self, ...}: {
  flake.nixosModules.nixos-management = {
    lib,
    pkgs,
    config,
    ...
  }: let
    repository = "ssh://git@git.lumilukko.com:2222/pete/nixos.git";
    notifyUpdateFailure = pkgs.writeShellApplication {
        name = "nixos-auto-update-notify-failure";
        runtimeInputs = with pkgs; [
          coreutils
          curl
          systemd # systemctl, journalctl
        ];
        text = ''
          unit="nixos-auto-update.service"

          result="$(systemctl show -p Result --value "$unit" || echo unknown)"
          status="$(systemctl show -p ExecMainStatus --value "$unit" || echo unknown)"
          logs="$(journalctl -u "$unit" -n 15 --no-pager -o cat 2>&1 || true)"

          curl --silent --show-error --fail \
            --retry 5 --retry-delay 10 --retry-all-errors \
            --connect-timeout 5 --max-time 20 \
            -H "Title: nixos-auto-update FAILED" \
            -H "Priority: high" \
            -d "Auto-update failed on ${config.networking.hostName} (result: $result, exit status: $status)

          $logs" \
            ${lib.escapeShellArg config.nixos-management.gitops.ntfyFailure}
        '';
      };
    update = self.lib.mkScript pkgs {
      name = "update";
      src = ./scripts/update.sh;

      runtimeInputs = with pkgs; [
        coreutils # mktemp, rm
        git
        nix
        openssh
      ];

      substitutions = {
        REPOSITORY = repository;
      };
    };

    gitops = self.lib.mkScript pkgs {
      name = "gitops";
      src = ./scripts/gitops.sh;

      runtimeInputs = with pkgs; [
        coreutils
        curl
        git
        nix
        nixos-rebuild
        openssh
        systemd
      ];

      substitutions = {
        REPO_URL = repository;
        NTFY_SUCCESS_URL = config.nixos-management.gitops.ntfyUpgrade;
        NTFY_FAILURE_URL = config.nixos-management.gitops.ntfyFailure;
        KEEP_GENERATIONS = toString config.nixos-management.gitops.keepGenerations;
        CACHE_URL = self.lib.fleet.cache.url;
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
        keepGenerations = lib.mkOption {
          type = lib.types.ints.between 2 1000;
          default = 5;
          example = 2;
          description = ''
            System generations to keep, including the one being deployed.
            Older ones are pruned on every update, which also bounds the number
            of boot entries. The bootloader may add the new generation before
            it removes the oldest, so small boot partitions need a low value.
          '';
        };
        ntfyFailure = lib.mkOption {
          type = lib.types.str;
          default = self.lib.fleet.ntfyFailure config.hostname;
          description = "ntfy URL for gitops failure notifications.";
        };
        ntfyUpgrade = lib.mkOption {
          type = lib.types.str;
          default = self.lib.fleet.ntfyUpgrade config.hostname;
          description = "ntfy URL for gitops successful upgrade notifications.";
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
          after = ["network-online.target"];
          wants = ["network-online.target"];

          # Runs for any failure: script error, exec failure, timeout, signal.
          onFailure = ["nixos-auto-update-failure.service"];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${update}/bin/update";
            TimeoutStartSec = "1h";
          };
        };
        systemd.services.nixos-auto-update-failure = {
          description = "Notify that nixos-auto-update failed";
          after = ["network-online.target"];
          wants = ["network-online.target"];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${notifyUpdateFailure}/bin/nixos-auto-update-notify-failure";
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
        # The rebuild runs inside this unit, so the switch must not
        # restart or stop the service that is performing it.
        systemd.services.gitops = {
          description = "Check remote NixOS config repo for updates";
          restartIfChanged = false;
          stopIfChanged = false;
          after = ["network-online.target"];
          wants = ["network-online.target"];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${gitops}/bin/gitops";
            # Creates /var/lib/gitops (holds the clone and state files).
            StateDirectory = "gitops";
            TimeoutStartSec = "2h";
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
