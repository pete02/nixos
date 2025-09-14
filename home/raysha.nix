{ lib, osConfig, ... }:
{
  home.username = "pete";
  home.homeDirectory = "/home/pete";

  home.stateVersion = "25.05";
  imports = [
    ./configs/hyprland.nix
    ./configs/hyprpanel.nix
    ./configs/vscode.nix
  ];

  home.sessionVariables = {
    QT_QPA_PLATFORM = "wayland brave";
  };

  programs.home-manager.enable = true;

  wayland.windowManager.hyprland = lib.mkIf osConfig.enable.hyprland {
    importantPrefixes = [ "output" ];
    settings = {
      exec-once = "sleep 5 && xrandr --output DP-2 --primary";
      monitor = [
        "desc:Eizo Nanao Corporation EV2436W 38144035,1920x1080,3440x0,1"
      ];
      monitorV2 = {
        output = "DP-2";
        mode = "3440x1440@175";
        position = "0x0";
        scale = "1";
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
