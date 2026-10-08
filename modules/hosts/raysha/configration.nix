{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.rayshaConfiguration = {
    pkgs,
    lib,
    config,
    ...
  }: {
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
      android-tools
    ];

    username = "pete";

    connectivity = {
      bluetooth = true;
      wireless = true;
    };

    management = {
      gitClient = true;
      sshClient = true;
      ld = true;
    };

    common-tools.books = true;
    gaming.sunshine.enable = true;
    services = {
      cleaner = true;
      mDNS = true;
      sambaClient = true;
      autoUpdate = true;
    };

    users.users.pete.extraGroups = ["adbusers"];

    hyprlandExtraConfig = ''
      monitor = desc:Dell Inc. AW3425DW DD5H274, 3440x1440@175, 0x0, 1, bitdepth, 10
      monitor = desc:AOC Q32G1WG4 0x00000669, 2560x1440@120, 3440x0, 1
      monitor = HDMI-A-1,3840x2160@59.97,auto,1


      misc {
        force_default_wallpaper = 2
      }

      bind = SUPER, right, movetoworkspace, 1
      bind = SUPER, left, movetoworkspace, 2
      bind = SUPER, n, exec, /home/pete/wallpapers/switch.sh
    '';
  };
}
