{pkgs, ...}: {
  hardware.keyboard.qmk.enable = true;
  services.udev.packages = with pkgs; [
    via
  ];

  backups = {
    git-sync = {
      enable = true;
      folders = ["/home/pete/code"];
    };
    restic = {
      enable = true;
      repository = "/mnt/server/desktopsync";
      folders = ["/home/pete/school" "/home/pete/savegames"];
      exclude = ["node_modules" "target" ".cache" ".direnv" "__pycache__"];
    };
  };

  username = "pete";

  healthcheck = {
    enable = true;
    devices = ["/dev/sda" "/dev/nvme0n1" "/dev/nvme1n1"];
    memSize = "1G";
    mdadm = {
      enable = true;
      devices = ["md127"];
    };
  };

  nixbuilder.cache.client.enable = true;

  connectivity = {
    bluetooth = true;
    wifi = {
      enable = true;
      Ssid = "Pete";
    };
    mDNS = true;
  };
  ssh.client.enable = true;
  nixos-management.gitops.enable = true;

  samba.clients.server.enable = true;
  samba.clients.timelock.enable = true;

  desktop.desktop = "raysha";
  desktop.monitors = [
    {
      output = "desc:Dell Inc. AW3425DW DD5H274";
      mode = "3440x1440@175";
      bitdepth = 10;
    }
    {
      output = "desc:AOC Q32G1WG4 0x00000669";
      mode = "2560x1440@120";
      position = "3440x0";
    }
  ];
}
