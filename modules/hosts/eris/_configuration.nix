{pkgs, ...}: {
  system.stateVersion = "26.05";
  username = "pete";
  hostname = "eris";
  nixbuilder={
    cache.client.enable = true;
    usesBuilders=true;
  };
  connectivity={
    mDNS = true;
    wireguard = true;
  };

  samba.servers.rpi = {
    enable = true;
    credentialsSecret = "samba/rpi";

    shares.rpi = {
      path = "/data/rpi";
    };
  };

  dev.git = true;
  nixos-management.gitops.enable = true;

  environment.systemPackages = with pkgs; [
    kitty.terminfo
  ];
}
