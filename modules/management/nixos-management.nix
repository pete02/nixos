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
    if sudo nixos-rebuild switch --flake "/etc/nixos#$HOSTNAME" --impure; then
        echo "Rebuild successful"
        nvd diff $(ls -d1v /nix/var/nix/profiles/system-*-link|tail -n 2) > /etc/nixos/diff.txt
        cat /etc/nixos/diff.txt
        git add /etc/nixos/diff.txt
        git commit --amend --no-edit
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

  environment.systemPackages = [
    pkgs.nixfmt-tree
    pkgs.libnotify
    pkgs.nvd
    pkgs.vulnix
    pkgs.lm_sensors
    pkgs.neofetch
    rebuild-script
  ];

  nix.gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-older-than 7d";
  };

  nix.settings.auto-optimise-store = true;
  services.cleaner.enable = true;
  services.autoupdater.enable = true;
}
