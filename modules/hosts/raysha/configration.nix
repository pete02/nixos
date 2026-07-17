{ self, inputs, ... }: {
  flake.nixosModules.rayshaConfiguration =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    {
      imports = [
        self.nixosModules.hyprland
        self.nixosModules.sops
        self.nixosModules.dev
        self.nixosModules.gaming
        self.nixosModules.common
        self.nixosModules.mdadm
      ];

      environment.systemPackages = with pkgs; [
        via
      ];


      hardware.keyboard.qmk.enable = true;
      services.udev.packages = with pkgs; [
        via
      ];

      username = "pete";
      hostname = "raysha";
      connectivity = {
        bluetooth = true;
        wireless = true;
      };

      management = {
        sshClient = true;
        ld = true;
      };

      common-tools.books = true;

      services = {
        cleaner = true;
        mDNS = true;
        sambaClient = true;
        autoUpdate = true;
      };

      hyprlandExtraConfig = ''
        monitor = desc:Dell Inc. AW3425DW DD5H274, 3440x1440@175, 0x0, 1, bitdepth, 10
        monitor = desc:Eizo Nanao Corporation EV2436W 38144035, 1920x1080, 3440x0, 1

        misc {
          force_default_wallpaper = 2
        }

        bind = SUPER, right, movetoworkspace, 1
        bind = SUPER, left, movetoworkspace, 2
        bind = SUPER, n, exec, /home/pete/wallpapers/switch.sh
        bind = SUPER, ö, exec, echo "hello"

        debug {
          full_cm_proto = true
          disable_logs = false
        }
      '';
    };
}
