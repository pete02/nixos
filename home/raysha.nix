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
}
