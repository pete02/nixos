{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    via
    rstudio
  ];

  hardware.keyboard.qmk.enable = true;
  services.udev.packages = with pkgs; [
    via
  ];

  username = "pete";
  hostname = "talia";
  connectivity = {
    bluetooth = true;
    wifi.enable = true;
    mDNS = true;
  };
  ssh.client.enable = true;

  dev = {
    enable = true;
    vscode = true;
    ld = true;
    git = true;
  };

  nixbuilder.cache.client.enable=true;
  
  common-tools.books = true;
  common-tools.school = true;

  samba.clients.server = {
    enable = true;
    host = "aria.local";
    share = "server";
    mountPoint = "/mnt/server";
    credentialsSecret = "samba/server";
  };

  desktop = {
    enable = true;
    services = {
      cleaner = true;
    };
  };
}
