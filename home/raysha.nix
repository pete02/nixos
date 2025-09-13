{ ... }:
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
      exec-once = [
        ''${pkgs.swaylock}/bin/swaylock -f''
      ];
      monitor = [
        "DP-5,3440x1440,0x0,1"
        "DP-4,1920x1080,3440x0,1"
      ];
    };
  };
}
