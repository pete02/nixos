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

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nixpkgs.config.allowUnfree = true;

  system.autoUpgrade = {
    enable = true;
    dates = "weekly";
  };

  nix.gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-older-than 10d";
  };

  nix.settings.auto-optimise-store = true;

  hyprland.enable = true;
  dev.enable = true;

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
      "pete" = import ./../../home/home.nix;
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
