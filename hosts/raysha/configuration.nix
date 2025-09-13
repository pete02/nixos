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
  nvidia.enable = true;

  networking.hostName = "raysha";

  users.users.pete = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
    ];
  };
  home-manager = {
    useGlobalPkgs = true;
    extraSpecialArgs = { inherit inputs; };
    users = {
      "pete" = import ./../../home/raysha.nix;
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
    lshw
    xrandr
  ];

  system.stateVersion = "25.05";

}
