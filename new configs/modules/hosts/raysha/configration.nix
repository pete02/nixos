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
      ];

      environment.systemPackages = with pkgs;[
        mdadm
      ];

      username = "pete";
      connectivity = {
        bluetooth = true;
        wireless = true;
      };

      management = {
        sshClient = true;
        ld = true;
      };

      common-tools.books=true;

      services = {
        cleaner = true;
        sambaClient=true;
      };

      hyprlandExtraConfig = ''
        monitorv2 = desc:Dell Inc. AW3425DW DD5H274, 3440x1440@175, 0x0, 1, bitdepth, 10
        monitorv2 = desc:Eizo Nanao Corporation EV2436W 38144035, 1920x1080, 3440x0, 1

        misc {
          force_default_wallpaper = 2
        }

        bind = SUPER, right, movetoworkspace, 1
        bind = SUPER, left, movetoworkspace, 2
        bind = SUPER, n, exec, /home/pete/wallpapers/switch.sh

        debug {
          full_cm_proto = true
          disable_logs = false
        }
      '';
    };
}
