{
  pkgs,
  lib,
  config,
  ...
}: {
  username = "pete";
  dev = {
    enable = true;
    ld = true;
    git = true;
  };

  common-tools.books = true;
  connectivity.mDNS = true;

  environment.sessionVariables = {
    MAILADDR = "petrik.rasanen@gmail.com";
  };

  health-check = {
    enable = true;
    devices = ["/dev/sda" "/dev/sdb" "/dev/nvme0n1"];
    bcachefs = {
      enable = true;
      devices = [
        "sda"
        "sdb1"
        "nvme0n1p2"
      ];
    };
  };


  gaming={
    sunshine=true;
    compatibility = true;
  };
  nixos-management = {
    auto-update = true;
    gitops = true;
  };

  bitwarden-backup = {
    enable = true;
    dataDir = "/mnt/server/Serversetup/data/vaultwarden";
    containerName = "vaultwarden";
    ntfyUrl = "https://ntfy.lumilukko.com/Aria";
    rcloneConfigFile = config.sops.secrets.rclone-gdrive-config.path;
  };

  environment.systemPackages = with pkgs; [
    kitty.terminfo
  ];

  nixbuilders.cache.server = {
    enable = true;
    apiEndpoint = "http://192.168.88.241:8080/";
    envSecret = "services/attic/env";
    openFirewall = true; # restrict to LAN/docker subnet if you can
  };

  sambaTimelock.server = true;
  samba.server = true;
}
