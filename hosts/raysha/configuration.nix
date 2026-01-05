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
      enable = false;
      interface = "enp12s0";
      dhcp = true;
    };

    networking.useNetworkd = true;
    networking.enableIPv6 = true;
    services.resolved.enable = true;
    networking.dhcpcd.enable = false;

    systemd.network.networks."10-wired" = {
      matchConfig.Name = "enp12s0"; # replace with your NIC name
      networkConfig.DHCP = "yes";
      dhcpConfig = {
        ClientIdentifier = "mac";
        UseDomains = "true";
        CriticalConnection = "true";
      };
    };

    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
      silent = true;
    };

    programs.nix-ld.enable = true;
    username = "pete";
    home-manager.users.pete = import ./../../home/raysha.nix;

    programs.firefox.enable = true;
    environment.systemPackages = with pkgs; [
      vim
      wget
      gimp
      git
      zip
      unzip
      unrar
      swww
      kdePackages.dolphin
      htop
      kdePackages.kcalc
      tree
      lshw
      ffmpeg
      mdadm
      calibre
      libreoffice
    ];
    system.stateVersion = "25.05";
  };
}
