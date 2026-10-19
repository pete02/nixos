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

  healthcheck = {
    enable = true;
    devices = ["/dev/sda" "/dev/sdb" "/dev/nvme0n1"];
    ntfyUrl = "https://ntfy.lumilukko.com/Raysha";
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
    ntfyUrl = "https://ntfy.lumilukko.com/Aria";
    rcloneConfigFile = config.sops.secrets.rclone-gdrive-config.path;
  };

  environment.systemPackages = with pkgs; [
    kitty.terminfo
  ];
  services.timelock.enable = true;

  nixbuilder.cache= {
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

  samba.timelock.server = true;
  samba.server = true;

  desktop = {
    enable = true;
    hyprland = {
      enable = true;
      extraConfig = ''

        hl.config({
          misc = {
            force_default_wallpaper = 2,
          },
        })


        -- Philips TV: right of AOC
        hl.monitor({
            output = "HDMI-A-1",
            mode = "3840x2160@59.97",
            position = "0x0",
            scale = 1,
        })

        hl.workspace_rule({
            workspace = "1",
            monitor = "HDMI-A-1",
            default = true,
        })

      '';
    };
  };
}
