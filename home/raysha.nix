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
    GDK_BACKEND = "wayland,x11";
    QT_QPA_PLATFORM = "wayland;xcb";
    #SDL_VIDEODRIVER = "x11";
    CLUTTER_BACKEND = "wayland";
    XDG_CURRENT_DESKTOP = "Hyprland";
    XDG_SESSION_TYPE = "wayland";
    XDG_SESSION_DESKTOP = "Hyprland";
    WLR_NO_HARDWARE_CURSORS = "1";
  };

  programs.home-manager.enable = true;

  wayland.windowManager.hyprland = lib.mkIf osConfig.enable.hyprland {
    importantPrefixes = [ "output" ];
    settings = {
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
