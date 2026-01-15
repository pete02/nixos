{ lib, osConfig, ... }:
{
  home.username = "pete";
  home.homeDirectory = "/home/pete";

  home.stateVersion = "25.05";
  imports = [
    ./configs
  ];

  programs.home-manager.enable = true;

  wayland.windowManager.hyprland = lib.mkIf osConfig.desktops.hyprland {
    importantPrefixes = [ "output" ];
    settings = {
      environment = {

      };
      exec-once = "sleep 5 && xrandr --output DP-2 --primary && dunst";
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

      bind = [
        "SUPER, right, movetoworkspace, 1"
        "SUPER, left, movetoworkspace, 2"
        "SUPER, n,exec, /home/pete/wallpapers/switch.sh"
      ];

      debug = {
        full_cm_proto = true;
        disable_logs = false;
      };
    };
  };
}
