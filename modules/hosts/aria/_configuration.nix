{
  pkgs,
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

  healthcheck = {
    enable = true;
    devices = ["/dev/sda" "/dev/sdb" "/dev/nvme0n1"];
    bcachefs = {
      enable = true;
      uuid = "6efc72dc-a79e-4340-adf0-28ceb1be8769";
      devices = [
        "hdd.hdd1"
        "hdd.hdd2"
        "sdd.sdd1"
      ];
    };
  };

  gaming = {
    sunshine = true;
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
    rcloneConfigFile = config.sops.secrets.rclone-gdrive-config.path;
  };

  environment.systemPackages = with pkgs; [
    kitty.terminfo
  ];
  services.timelock.enable = true;

  nixbuilder.cache = {
    server = {
      enable = true;
      apiEndpoint = "http://192.168.88.241:8080/";
      envSecret = "services/attic/env";
      openFirewall = true; # restrict to LAN/docker subnet if you can
    };
    client = {
      enable = true;
      url = "http://192.168.88.241:8080/main";
      publicKey = "main:i1t81gc6fOtVfDvKgpiL1LG5HjrWF7AtHD21rmbr1OI=";
      pullTokenSecret = "services/attic/pull_token";
    };
  };

  samba.timelock.enable = true;

  samba.servers.server = {
    enable = true;
    credentialsSecret = "samba/server";

    shares.server = {
      path = "/mnt/server";
    };
  };

  desktop.enable = true;
}
