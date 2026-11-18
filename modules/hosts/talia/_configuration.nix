{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    via
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
  };

  nixbuilder.cache.client.enable = true;
  nixos-management.gitops.enable = true;
  common-tools.books = true;
  ssh.server.passwordlogin = true;

  desktop.desktop = "talia";
  desktop.monitors = [
    {
      output = "desc:Samsung Display Corp. 0x4156";
      mode = "1920x1080";
      bitdepth = 10;
    }
    {
      output = "desc:Dell Inc. AW3425DW DD5H274";
      mode = "3440x1440@175";
      position = "1080x0";
      bitdepth = 10;
    }
  ];
}
