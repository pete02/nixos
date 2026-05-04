{ lib, osConfig, ... }:
{
  home.username = "pete";
  home.homeDirectory = "/home/pete";

  home.stateVersion = "25.05";
  imports = [
    ./configs
  ];

  programs.git = {
    extraConfig = {
      merge."ours" = {
        name = "Keep ours on conflict";
        driver = "true";
      };
    };
  };

  programs.home-manager.enable = true;

  programs.hyprpanel.settings.bar.layouts."*".right = lib.mkIf osConfig.desktops.hyprpanel [
    "network"
    "bluetooth"
  ];

  programs.hyprpanel.settings.bar.layouts."*".right = lib.mkIf osConfig.desktops.hyprpanel [
    "network"
    "bluetooth"
  ];

  wayland.windowManager.hyprland = lib.mkIf osConfig.desktops.hyprland {
    importantPrefixes = [ "output" ];
    settings = {
      environment = {

      };
      exec-once = "sleep 5  && dunst && xrandr --output $(xrandr | grep ' connected' | grep '3440x1440' | cut -d' ' -f1) --primary";

      monitorv2 = [
        {
          output = "desc:Dell Inc. AW3425DW DD5H274";
          mode = "3440x1440@175";
          position = "0x0";
          scale = 1;
          bitdepth = 10;
          supports_wide_color = 1;
          supports_hdr = 1;
          sdr_max_luminance = 250;
          max_luminance = 1000;
        }
        {
          output = "desc:Eizo Nanao Corporation EV2436W 38144035";
          scale = 1;
          mode = "1920x1080";
          position = "3440x0";
        }

      ];

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
