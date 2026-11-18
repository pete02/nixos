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

  streaming.desktops = {
    enable = true;
    parentInterface = "enp4s0"; # aria's real NIC name
    desktops.aria = {
      desktop.name = "raysha";
      outputs = [
        {
          mode = "3440x1440@60";
          ip = "192.168.88.2";
        }
      ];
      # tmpfs /home/user is root-owned, so the unprivileged container user
      # cannot create ~/.local/state (wireplumber noise); the bind-mounted
      # home from tmpfiles is owned by uid:gid instead
      persistentHome = true;
      # the container user must belong to the host's `video` group (gid 26,
      # see getent group video) or Hyprland cannot open /dev/dri/card1
      # (crw-rw---- root video 0660) and its DRM backend dies with
      # `CBackend::create() failed!`.
      extraGids = [
        26 # `video`: /dev/dri/card1 is root:video 0660, Hyprland's DRM backend needs it
        992 # `uinput`: /dev/uinput is root:uinput 0660, Sunshine opens it to create devices
        174 # `input`: the /dev/input event nodes (incl. Sunshine's uinput devices) are
        # root:input 0660; Hyprland's libinput backend must open them to see them
      ];
    };
  };

  gaming.compatibility = true;

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
