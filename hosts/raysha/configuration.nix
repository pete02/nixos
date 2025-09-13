{
  pkgs,
  inputs,
  ...
}:
let
  mdadmconfigfile = ''
    ARRAY /dev/md0 metadata=1.2 UUID=8a67d8ca:4673ed91:8321e81c:499d8f01
  '';
in
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
    xrandr
  ];
  system.stateVersion = "25.05";

}
