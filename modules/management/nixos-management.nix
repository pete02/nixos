{
  pkgs,
  ...
}:
let
  rebuild-script = pkgs.writeShellScriptBin "rebuild" ''
    cd /etc/nixos
    set -euo pipefail
    HOSTNAME=$(hostname)

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
    if sudo nixos-rebuild switch --flake "/etc/nixos#$HOSTNAME"; then
        echo "Rebuild successful"
        nvd diff $(ls -d1v /nix/var/nix/profiles/system-*-link|tail -n 2)
        git push
    else
        echo "Rebuild failed, not pushing."
        exit 1
    fi


  '';
in
{
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nixpkgs.config.allowUnfree = true;

  nix.gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-older-than 10d";
  };

  environment.systemPackages = [
    pkgs.nixfmt-tree
    pkgs.libnotify
    pkgs.nvd
    pkgs.vulnix
    rebuild-script
  ];

  nix.settings.auto-optimise-store = true;
  systemd.user.services.update-nixos-config = {
    description = "Auto-update NixOS config + flakes at boot";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      Type = "simple";
      Environment = ''
        PATH=/run/current-system/sw/bin:/run/current-system/profile/bin:/usr/bin:/bin
      '';
      ExecStart = "${pkgs.writeShellScript "update-nixos-config" ''
        set -ex
        until ping -c1 github.com >/dev/null 2>&1; do
          sleep 10
        done

        cd /etc/nixos
        flaked=0
        pulled=0

        # Git pull as user
        echo "start fetching"
        if ! git pull --ff-only | grep -q "Already up to date"; then
          pulled=1
        fi
        echo "fetched from git"
        # Flake update as user
        nix flake update
        if ! git diff --quiet flake.lock; then
          git add flake.lock
          git commit -m "Auto-update flake inputs"
          git push origin master
          flaked=1
        fi

        if [ "$pulled" -eq 1 ] || [ "$flaked" -eq 1 ]; then
          msg="System ready for rebuild:"
          if [ "$pulled" -eq 1 ]; then
              msg="$msg \n- configuration pulled"
          fi
          if [ "$flaked" -eq 1 ]; then
              msg="$msg \n- flake updated"
          fi
          notify-send "NixOS" "$msg"
        fi
      ''}";
    };
  };
}
