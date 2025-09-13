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

  wayland.windowManager.hyprland = lib.mkIf osConfig.hyprland.enable {
    settings = {
      monitor = [
        "desc:Dell Inc. Dell AW3423DW '#GjMYMxgwAAFt',preferred,auto,1"
        "DP-1,preferred,auto,1"
      ];
      misc = {
        force_default_wallpaper = 2;
      };
    };
  };
}
