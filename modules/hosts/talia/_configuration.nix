{
  pkgs,
  lib,
  config,
  ...
}: {
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
  ssh.client = true;

  dev = {
    enable = true;
    vscode = true;
    ld = true;
    git = true;
  };

  nixbuilder.cache.client = {
    enable = true;
    url = "http://192.168.88.241:8080/main";
    publicKey = "main:i1t81gc6fOtVfDvKgpiL1LG5HjrWF7AtHD21rmbr1OI=";
    pullTokenSecret = "services/attic/pull_token";
  };
  common-tools.books = true;
  common-tools.school = true;
  samba.client = true;
  desktop = {
    enable = true;
    services = {
      cleaner = true;
    };

    hyprland = {
      enable = true;
      extraConfig = ''
        hl.config({
          monitor = {
            "desc:Lenovo Group Limited 0x9052,1920x1080,0x0,1",
            "desc:Dell Inc. AW3425DW DD5H274,3440x1440@175,1920x0,1,bitdepth,10",
          },

          misc = {
            force_default_wallpaper = 2,
          },
        })

        hl.bind("SUPER + RIGHT",
          hl.dsp.exec_cmd("hyprctl dispatch movetoworkspace 1"))

        hl.bind("SUPER + LEFT",
          hl.dsp.exec_cmd("hyprctl dispatch movetoworkspace 2"))
      '';
      extraWayleConfig = ''
        [[bar.layout]]
        monitor = "*"
        right = [
          "volume",
          "netstat",
          "clock",
          "systray",
          "notifications",
          "network",
          "bluetooth",
          "battery",
        ]
      '';
    };
  };
}
