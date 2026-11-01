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
    gitops.enable = true;
  };

  backups = {
    bitwarden = {
      enable = true;
      dataDir = "/mnt/server/Serversetup/data/vaultwarden";
      containerName = "vaultwarden";
      rcloneConfigFile = config.sops.secrets.rclone-gdrive-config.path;
    };
    restic = {
      enable = true;
      user = "root";
      repository = "/mnt/rpi/restic/${config.networking.hostName}";
      passwordSecret = "restic/aria";

      folders = [
        "/mnt/server"
        "/mnt/timelock"
      ];

      exclude = [
        "node_modules"
        "target"
        "/mnt/rpi"
        ".cache"
        ".trash"
        ".Trash-1000"
        "nix-store"
        ".direnv"
        "__pycache__"
      ];

      schedule = "*-*-* 00:00:00";

      pruneOpts = [
        "--keep-daily"
        "7"
        "--keep-weekly"
        "5"
        "--keep-monthly"
        "12"
      ];
    };
  };

  environment.systemPackages = with pkgs; [
    kitty.terminfo
  ];
  services.timelock.enable = true;
  ssh.client.enable = true;
  nixbuilder.cache.client.enable = true;
  nixbuilder.cache.server.openFirewall = true;

  samba.timelock.enable = true;

  samba.servers.server = {
    enable = true;
    credentialsSecret = "samba/server";

    shares.server = {
      path = "/mnt/server";
    };
  };
  samba.clients.rpi.enable = true;

  desktop.enable = true;
}
