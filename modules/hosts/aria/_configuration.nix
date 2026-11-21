{
  pkgs,
  config,
  ...
}: {
  username = "pete";
  dev = {
    enable = true;
    ld = true;
  };

  common-tools.books = true;
  connectivity.mDNS = true;
  services.avahi.allowInterfaces = ["enp4s0"];
  boot.kernel.sysctl."net.ipv4.igmp_max_memberships" = 100;


  environment.sessionVariables = {
    MAILADDR = "petrik.rasanen@gmail.com";
  };

  healthcheck = {
    enable = true;
    devices = ["/dev/sda" "/dev/sdb" "/dev/nvme0n1"];
  };

  streaming.podman = {
    enable = false;
    parentInterface = "enp4s0"; # aria's real NIC name

    containers.aria = {
      ip = "192.168.88.2";
      persistentHome = true;
      config = {
        system.stateVersion = "26.05";
        username = "pete";
        desktop.desktop = "raysha";
        desktop.monitors = [
          {
            output = "desk-1";
            mode = "3440x1440@175";
          }
        ];
      };
    };
  };

  gaming.compatibility = true;
  
  nixos-management = {
    auto-update = true;
    gitops.enable = true;
  };

  backups = {
    bitwarden = {
      enable = false;
      dataDir = "/mnt/server/Serversetup/data/vaultwarden";
      containerName = "vaultwarden";
      rcloneConfigFile = config.sops.secrets.rclone-gdrive-config.path;
    };
    restic = {
      enable = false;
      user = "root";
      repository = "sftp:eris-wg:/data/rpi/restic/aria";
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
}
