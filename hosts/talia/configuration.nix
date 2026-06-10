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
    school = true;
    sync = false;
    powersave = true;
    wireless = true;
    bluetooth = true;
    user = true;
    wireguardclient = false;
    brave = true;
  };

  desktops = {
    hyprland = true;
    hyprpanel = true;
  };

  networking.hostName = "talia";
  username = "pete";
  home-manager.users.pete = import ./../../home/talia.nix;

  smb = {
    enable = true;
    router = true;
    server = true;
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    silent = true;
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
    iw
  ];

  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc
      zlib
      glibc
      libgcc
      libffi
      openssl
    ];
  };

  system.stateVersion = "25.05";

}
