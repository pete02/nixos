{
  pkgs,
  lib,
  config,
  ...
}: {
  environment.systemPackages = with pkgs; [
    via
  ];

  hardware.keyboard.qmk.enable = true;
  services.udev.packages = with pkgs; [
    via
  ];

  username = "pete";

  healthcheck = {
    enable = true;
    devices = ["/dev/sda" "/dev/nvme0n1" "/dev/nvme1n1"];
    memSize = "1G";
    ntfyUrl = "https://ntfy.lumilukko.com/Raysha";
    mdadm = {
      enable = true;
      devices = ["md127"];
    };
  };

  connectivity = {
    bluetooth = true;
    wifi.enable = true;
    mDNS = true;
  };
  ssh.client = true;

  samba.timelock.client = true;

  common-tools.books = true;
  samba.client = true;

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
    hyprland = {
      enable = true;
      extraConfig = ''
        hl.config({
          monitor = {
            "desc:Dell Inc. AW3425DW DD5H274,3440x1440@175,0x0,1,bitdepth,10",
            "desc:AOC Q32G1WG4 0x00000669,2560x1440@120,3440x0,1",
            "HDMI-A-1,3840x2160@59.97,7000x0,1",
          },

          workspace = {
            "1, monitor:desc:Dell Inc. AW3425DW DD5H274",
            "2, monitor:desc:AOC Q32G1WG4 0x00000669",
            "10, monitor:HDMI-A-1",
          },

          misc = {
            force_default_wallpaper = 2,
          },
        })

        hl.bind("SUPER + LEFT",
          hl.dsp.exec_cmd("hyprctl dispatch movetoworkspace 1"))

        hl.bind("SUPER + RIGHT",
          hl.dsp.exec_cmd("hyprctl dispatch movetoworkspace 2"))

        hl.bind("SUPER + N",
          hl.dsp.exec_cmd("/home/pete/wallpapers/switch.sh"))

        hl.on("hyprland.start", function()
          hl.exec_cmd("hyprctl dispatch workspace 1")
        end)
      '';
    };
  };
}
