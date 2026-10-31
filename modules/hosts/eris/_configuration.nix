{pkgs, ...}: {
  system.stateVersion = "26.05";
  username = "pete";
  hostname = "eris";
  nixbuilder = {
    cache.client = {
      enable = true;
      cachePush = false;
    };
    usesBuilders = true;
  };

  nix.settings.max-jobs = 0;
  connectivity = {
    mDNS = true;
    wireguard.pihlajatie = {
      endpoint = "lumilukko.com:13231";
      allowed_ips = ["10.0.0.1/32" "192.168.88.0/24"];
      address = "10.0.0.3/32";
    };
  };

  healthcheck = {
    enable = true;
    devices = ["/dev/sda"];
    memSize = "128M";
    schedule = "Sun 12:00";
  };

  networking.hosts."192.168.88.241" = [
    "git.lumilukko.com"
    "ntfy.lumilukko.com"
  ];

  samba.servers.rpi = {
    enable = true;
    credentialsSecret = "samba/rpi";

    shares.rpi = {
      path = "/data/rpi";
    };
  };

  dev.git = true;
  nixos-management.gitops.enable = true;
  ssh.client.enable = true;
  environment.systemPackages = with pkgs; [
    kitty.terminfo
  ];
}
