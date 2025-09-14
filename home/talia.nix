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
    ./configs/hyprland.nix
    ./configs/hyprpanel.nix
    ./configs/vscode.nix
  ];

  home.sessionVariables = {
    QT_QPA_PLATFORM = "wayland brave";
  };

  programs.home-manager.enable = true;

  wayland.windowManager.hyprland = lib.mkIf osConfig.enable.hyprland {
    settings = {
      exec-once = [
        ''${pkgs.swaylock}/bin/swaylock -f''
      ];
      monitor = [
        "eDP-1,1920x1080,0x0,1"
        "HDMI-A-1,preferred,1920x0,1"
      ];
    };
  };

  programs.hyprpanel.settings.bar.layouts."*".right = lib.mkIf osConfig.enable.hyprpanel [
    "battery"
    "network"
  ];

}
