{ ... }:
{
  home.username = "pete";
  home.homeDirectory = "/home/pete";

  home.stateVersion = "25.05";
  imports = [
    ./hyprland.nix
    ./hyprpanel.nix
  ];

  home.sessionVariables = {
    # EDITOR = "emacs";
    QT_QPA_PLATFORM = "wayland brave";
  };

  programs.home-manager.enable = true;
}
