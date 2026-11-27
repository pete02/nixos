{pkgs, ...}: {
  system.stateVersion = "26.05";
  username = "pete";
  desktop.desktop = "alanna-test";

  nixbuilder = {
    cache.client = {
      enable = true;
      cachePush = false;
    };
    usesBuilders = true;
  };
  connectivity = {
    mDNS = true;
    wifi = {
      enable = true;
      Ssid = "Pete";
    };
  };

  healthcheck = {
    enable = true;
    devices = ["/dev/sda"];
    memSize = "128M";
    schedule = "Sun 12:00";
  };

  nixos-management.gitops.enable = true;
  ssh.client.enable = true;
  environment.systemPackages = with pkgs; [
    kitty.terminfo
    v4l-utils
  ];
}
