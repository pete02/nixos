{
  pkgs,
  inputs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./../../modules/modules.nix
    inputs.home-manager.nixosModules.default
  ];

  enable = {
    dev = true;
    hyprland = true;
    hyprpanel = true;
    school = true;
    powersave = true;
    wireless = true;
  };
  networking.hostName = "talia";
  username = "pete";

  programs.firefox.enable = true;

  environment.systemPackages = with pkgs; [
    vim
    wget
    git
    zip
    unzip
    brave
    kdePackages.dolphin
    tree
  ];

  system.stateVersion = "25.05";

}
