{ lib, osConfig, ... }:
{
  home.username = "pete";
  home.homeDirectory = "/home/pete";

  home.stateVersion = "25.05";
  imports = [
    ./configs/hyprland.nix
    ./configs/hyprpanel.nix
  ];

  home.sessionVariables = {
    QT_QPA_PLATFORM = "wayland brave";
  };

  programs.home-manager.enable = true;

  wayland.windowManager.hyprland = lib.mkIf osConfig.enable.hyprland {
    settings = {
      monitor = [
        "desc:Dell Inc. Dell AW3423DW,3440x1440@60,0x0,1,bitdepth,primary"
        "desc:Eizo Nanao Corporation EV2436W 38144035,1920x1080,3440x0,1"
      ];
      misc = {
        force_default_wallpaper = 2;
      };
    };
  };
}
