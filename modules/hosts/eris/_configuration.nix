{pkgs, ...}: {
  system.stateVersion = "26.05";
  username = "pete";
  hostname = "eris";
  nixbuilder={
    cache.client.enable = true;
    usesBuilders=true;
  };
  connectivity.mDNS = true;
  connectivity.wifi = {
    enable = true;
    Ssid = "Pete";
  };

  dev.git = true;
  nixos-management.gitops.enable = true;

  environment.systemPackages = with pkgs; [
    kitty.terminfo
  ];
}
