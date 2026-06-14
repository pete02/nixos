{
  pkgs,
  inputs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./boot.nix
    ./features.nix
    ./../../modules
    inputs.home-manager.nixosModules.default
  ];
  config = {

    networking.hostName = "raysha";

    net = {
      enable = true;
      interface = "enp12s0";
      dhcp = false;
      address = "192.168.88.254/24";
      gateway = "192.168.88.1";
    };

    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
      silent = true;
    };

    programs.nix-ld.enable = true;
    username = "pete";
    home-manager.users.pete = import ./../../home/raysha.nix;

    nixpkgs.overlays = [
      (final: prev: {
        openldap = prev.openldap.overrideAttrs (old: {
          doCheck = false;
        });
      })
    ];

    programs.firefox.enable = true;
    environment.systemPackages = with pkgs; [
      vim
      wget
      gimp
      git
      zip
      unzip
      unrar
      sops
      awww
      kdePackages.dolphin
      htop
      kdePackages.kcalc
      tree
      lshw
      ffmpeg
      mdadm
      calibre
    ];
    system.stateVersion = "25.05";
  };
}
