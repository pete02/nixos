{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    via
    moonlight-qt
  ];

  hardware.keyboard.qmk.enable = true;
  services.udev.packages = with pkgs; [
    via
  ];

  backups.git-sync={
    enable=true;
    folders = [/home/pete/code]
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
    wifi.enable = true;
    mDNS = true;
  };
  ssh.client.enable = true;

  common-tools.books = true;
  samba.clients.server.enable = true;
  samba.clients.timelock.enable = true;

  gaming = {
    steam = true;
    sunshine = true;
    rpcs3 = true;
    performance = true;
    graphics = true;
    compatibility = true;
  };

  dev = {
    enable = true;
    vscode = true;
    android = true;
    ld = true;
    git = true;
  };

  desktop = {
    enable = true;
    services = {
      cleaner = true;
    };
  };
}
