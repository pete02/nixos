{
  pkgs,
  inputs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./../../modules
    ./boot.nix
    inputs.home-manager.nixosModules.default
  ];
  nixpkgs.config.allowUnfree = true;
  enable = {
    dev = true;
    hyprland = true;
    hyprpanel = true;
    school = true;
    powersave = true;
    wireless = true;
    bluetooth = true;
    user = true;
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
