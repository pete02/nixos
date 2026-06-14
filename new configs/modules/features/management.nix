{self,inputs,pkgs, ...}:{
  flake.nixosModules.management={config, lib,pkgs, ...}:let
      rebuild-script = pkgs.writeShellScriptBin "rebuild" ''
        cd /etc/nixos
        set -euo pipefail
        HOSTNAME=$(hostname)
        UNSTABLE_BRANCH="rebuild-unstable/$HOSTNAME"
        nix flake check

        if ! treefmt --no-cache --tree-root /etc/nixos &>/dev/null; then
            echo "treefmt failed, running for output:"
            treefmt --no-cache --tree-root  /etc/nixos
            exit 1
        fi
        git add /etc/nixos/.

        # Shows your changes
        git diff -U0 '*.nix'

        git commit -am "Rebuild on $HOSTNAME: $(date '+%Y-%m-%d %H:%M:%S')" || echo "No changes to commit."
        echo "Rebuilding system for $HOSTNAME..."
        echo "Please insert password for nixos-rebuild"

        if sudo nixos-rebuild switch --flake "/etc/nixos#$HOSTNAME" --impure; then
            echo "Rebuild successful"

            nvd diff $(ls -d1v /nix/var/nix/profiles/system-*-link|tail -n 2) > /etc/nixos/diff.txt
            cat /etc/nixos/diff.txt
            git add /etc/nixos/diff.txt

            CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
            if [[ "$CURRENT_BRANCH" == "$UNSTABLE_BRANCH" ]]; then
              git commit --amend --no-edit
              git push origin "$UNSTABLE_BRANCH"
              git checkout master
              git pull --rebase origin master
              git merge --no-ff "$UNSTABLE_BRANCH" -m "Merge successful rebuild from $UNSTABLE_BRANCH"
              git push origin master
              git push origin --delete "$UNSTABLE_BRANCH"
            else
              git commit --amend --no-edit
              git pull --rebase origin master
              git push origin master
            fi
        else
            echo "Rebuild failed, not pushing."
            if git show-ref --quiet refs/heads/"$UNSTABLE_BRANCH"; then
                git checkout "$UNSTABLE_BRANCH"
                git pull --rebase origin "$UNSTABLE_BRANCH"
            else
                git checkout -b "$UNSTABLE_BRANCH"
            fi
            git commit -am "Rebuild failed on $HOSTNAME: $(date '+%Y-%m-%d %H:%M:%S')" || echo "No changes to commit."
            git pull --rebase origin master
            git push -u origin "$UNSTABLE_BRANCH"

            exit 1
        fi
      '';
    in
    {
    options= {
      username= lib.mkOption {
        type = lib.types.str;
        description = "The username of the main user";
      };

      management= {
        powersave = lib.mkEnableOption "Enable power saving";
      };
    };
    config= lib.mkMerge [
      ({
        users.users.${config.username} = {
          isNormalUser = true;
          extraGroups = [
            "wheel"
            "seat"
            "dialout"
            "uucp"
          ];
        };
        time.timeZone = "Europe/Helsinki";
        i18n.defaultLocale = "fi_FI.UTF-8";

          nix.settings.experimental-features = [
            "nix-command"
            "flakes"
          ];
          nixpkgs.config.allowUnfree = true;
          environment.systemPackages = [
            pkgs.nixfmt-tree
            pkgs.libnotify
            pkgs.nvd
            pkgs.vulnix
            pkgs.lm_sensors
            pkgs.fastfetch
            rebuild-script
          ];

          nix.gc = {
            automatic = true;
            dates = "daily";
            options = "--delete-older-than 7d";
          };
          nix.settings.auto-optimise-store = true;

      })
      (lib.mkIf (config.management.powersave != null) {
          environment.systemPackages = with pkgs; [
            tlp
          ];

          services.thermald.enable = true;

          services.tlp = {
            settings = {
              CPU_BOOST_ON_AC = 1;
              CPU_BOOST_ON_BAT = 0;
              CPU_SCALING_GOVERNOR_ON_AC = "performance";
              CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
            };
          };
      })
    ];
  };
}