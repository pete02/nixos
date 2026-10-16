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
      android-tools
    ];

    username = "pete";

    health-check = {
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
      wireless = true;
    };
    ssh.client=true;
    git=true;
    management = {
      ld = true;
    };
    sambaTimelock.client=true;

    common-tools.books = true;
    sunshine.enable = true;
    samba.client=true;


    services = {
      cleaner = true;
      mDNS = true;
      autoUpdate = true;
    };

    users.users.pete.extraGroups = ["adbusers"];

    hyprlandExtraConfig = ''
      monitor = desc:Dell Inc. AW3425DW DD5H274, 3440x1440@175, 0x0, 1, bitdepth, 10
      monitor = desc:AOC Q32G1WG4 0x00000669, 2560x1440@120, 3440x0, 1
      monitor = HDMI-A-1,3840x2160@59.97,7000x0,1

      workspace = 1, monitor:desc:Dell Inc. AW3425DW DD5H274
      workspace = 2, monitor:desc:AOC Q32G1WG4 0x00000669
      workspace = 10, monitor:HDMI-A-1
      misc {
        force_default_wallpaper = 2
      }

      bind = SUPER, left, movetoworkspace, 1
      bind = SUPER, right, movetoworkspace, 2
      bind = SUPER, n, exec, /home/pete/wallpapers/switch.sh
      exec-once = hyprctl dispatch workspace 1

    '';
  }
