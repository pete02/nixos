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

  hyprland.enable = true;
  hyprpanel.enable = true;
  dev.enable = true;
  school.enable = true;

  powersave.enable = true;
  wireless.enable = true;

  networking.hostName = "talia";

  users.users.pete = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
  };
  home-manager = {
    useGlobalPkgs = true;
    extraSpecialArgs = { inherit inputs; };
    users = {
      "pete" = import ./../../home/talia.nix;
    };
  };

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
