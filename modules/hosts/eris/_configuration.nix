{pkgs, ...}: {
  system.stateVersion = "26.05";
  username = "pete";
  hostname = "eris";
  nixbuilder.cache.client.enable=true;
  connectivity.mDNS=true;
  connectivity.wifi = {
    enable = true;
    Ssid = "Pete";
  };

  dev.git = true;
  nixos-management.gitops = true;

  environment.systemPackages = with pkgs; [
    kitty.terminfo
  ];
}
