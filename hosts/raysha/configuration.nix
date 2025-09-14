{
  pkgs,
  inputs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./boot.nix
    ./../../modules/modules.nix
    inputs.home-manager.nixosModules.default
  ];

  enable = {
    dev = true;
    hyprland = true;
    hyprpanel = true;
    nvidia = true;
    gaming = true;
  };

  networking.hostName = "raysha";

  networking.useNetworkd = true;
  services.resolved.enable = true;
  networking.dhcpcd.enable = false;

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
    lshw
    mdadm
  ];
  system.stateVersion = "25.05";

}
