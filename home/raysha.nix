{
  lib,
  osConfig,
  pkgs,
  ...
}:
{
  home.username = "pete";
  home.homeDirectory = "/home/pete";

  home.stateVersion = "25.05";
  imports = [
    ./configs/hyprland.nix
    ./configs/hyprpanel.nix
    ./configs/vscode.nix
  ];

  systemd.user.services.update-nixos-config = {
    description = "Auto-update NixOS config + flakes at boot";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.writeShellScript "update-nixos-config" ''
        set -e
        until ping -c1 github.com >/dev/null 2>&1; do
          sleep 10
        done

        cd /etc/nixos
        changed=0

        # Git pull as user
        if ! pete git pull --ff-only | grep -q "Already up to date"; then
          changed=1
        fi

        # Flake update as user
        nix flake update
        if ! sudo -u pete git diff --quiet flake.lock; then
          git add flake.lock
          git commit -m "Auto-update flake inputs"
          push origin master
          changed=1
        fi

        if [ "$changed" -eq 1 ]; then
          sudo nixos-rebuild switch --flake /etc/nixos#$(hostname)
            notify-send "NixOS" "System configuration updated and rebuilt."
        fi
      ''}";
    };
  };

  programs.home-manager.enable = true;

  wayland.windowManager.hyprland = lib.mkIf osConfig.enable.hyprland {
    importantPrefixes = [ "output" ];
    settings = {
      environment = {

      };
      exec-once = "sleep 5 && xrandr --output DP-2 --primary";
      monitor = [
        "desc:Eizo Nanao Corporation EV2436W 38144035,1920x1080,3440x0,1"
      ];
      monitorv2 = {
        output = "DP-2";
        mode = "3440x1440@175";
        position = "0x0";
        scale = 1;
        bitdepth = 10;
        supports_wide_color = 1;
        supports_hdr = 1;
        sdr_max_luminance = 250;
        max_luminance = 1000;
      };
      misc = {
        force_default_wallpaper = 2;
      };

      debug = {
        full_cm_proto = true;
      };
    };
  };
}
