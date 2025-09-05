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

  networking.hostName = "talia";
  networking.wireless.enable = false;
  networking.networkmanager.enable = true;

  hyprland.enable = true;
  dev.enable = true;
  school.enable = true;
  powersave.enable = true;

  users.users.pete = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "docker" ];
    packages = with pkgs; [
      tree
    ];
  };

  home-manager = {
    useGlobalPkgs=true;
    extraSpecialArgs = {inherit inputs;};
    users= {
      "pete" = import ./../../home/home.nix;
    };
  };
  
  programs.firefox.enable = true;

  environment.systemPackages = with pkgs; [
    vim
    wget
    git
    zip
    brave
    kdePackages.dolphin
  ];

  system.stateVersion = "25.05";

}
