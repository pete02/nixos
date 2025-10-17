{
  pkgs,
  inputs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./boot.nix
    ./../../modules
    inputs.home-manager.nixosModules.default
  ];

  enable = {
    dev = true;
    hyprland = true;
    hyprpanel = true;
    nvidia = true;
    gaming = true;
    logitech = true;
    books = true;
    sync = true;
    user = true;
    brave = true;
  };

  networking.hostName = "raysha";

  environment.sessionVariables = {
    GDK_BACKEND = "wayland,x11";
    QT_QPA_PLATFORM = "wayland;xcb";
    CLUTTER_BACKEND = "wayland";
    XDG_CURRENT_DESKTOP = "Hyprland";
    XDG_SESSION_TYPE = "wayland";
    XDG_SESSION_DESKTOP = "Hyprland";
    WLR_NO_HARDWARE_CURSORS = "1";
    CHROME_PASSWORD_STORE = "basic";
    NIXOS_OZONE_WL = "0";
  };

  programs.direnv = {
    enable = true;
    # nix-direnv is used by default when direnv is enabled
    nix-direnv.enable = true;
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

  programs.nix-ld.enable = true;
  username = "pete";
  home-manager.users.pete = import ./../../home/raysha.nix;

  programs.firefox.enable = true;

  smb = {
    enable = true;
    router = false;
    server = true;
  };

  environment.systemPackages = with pkgs; [
    vim
    wget
    gimp
    git
    zip
    unzip
    unrar

    kdePackages.dolphin
    htop
    kdePackages.kcalc
    tree
    lshw
    ffmpeg
    mdadm
  ];
  system.stateVersion = "25.05";

}
