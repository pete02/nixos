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
    sync = false;
    powersave = true;
    wireless = true;
    bluetooth = true;
    user = true;
    wireguardclient = true;
    brave = true;
  };

  networking.hostName = "talia";
  username = "pete";
  home-manager.users.pete = import ./../../home/talia.nix;

  smb = {
    enable = true;
    router = false;
    server = true;
  };

  programs.firefox.enable = true;

  environment.systemPackages = with pkgs; [
    vim
    wget
    git
    zip
    unzip
    kdePackages.dolphin
    tree
  ];

  system.stateVersion = "25.05";

}
