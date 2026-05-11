{
  lib,
  pkgs,
  osConfig,
  ...
}:
{
  home.username = "pete";
  home.homeDirectory = "/home/pete";

  home.stateVersion = "25.05";
  imports = [
    ./configs
  ];

  home.sessionVariables = {
    QT_QPA_PLATFORM = "wayland brave";
  };

  programs.home-manager.enable = true;
  nixpkgs.config.allowUnfree = true;
  wayland.windowManager.hyprland = lib.mkIf osConfig.desktops.hyprland {
    settings = {
      exec-once = [
        "${pkgs.swaylock}/bin/swaylock -f"
      ];
      monitor = [
        "eDP-1,1920x1080,0x0,1"
        "HDMI-A-1,3440x1440@60,auto,1"
      ];

      bind = [
        "SUPER, left, movetoworkspace, 1"
        "SUPER, right, movetoworkspace, 2"
      ];
    };
  };

  programs.hyprpanel.settings.bar.layouts."*".right = lib.mkIf osConfig.desktops.hyprpanel [
    "network"
    "bluetooth"
    "battery"
  ];

}
