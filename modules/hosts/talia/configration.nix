{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.taliaConfiguration = {
    pkgs,
    lib,
    config,
    ...
  }: {
    imports = [
      self.nixosModules.hyprland
      self.nixosModules.sops
      self.nixosModules.dev
      self.nixosModules.common
    ];

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
      wireless = true;
    };

    management = {
      sshClient = true;
      ld = true;
    };

    common-tools.books = true;
    common-tools.school = true;

    services = {
      cleaner = true;
      sambaClient = true;
    };

    hyprlandExtraConfig = ''
      monitor = desc:Lenovo Group Limited 0x9052, 1920x1080, 0x0, 1
      monitor = desc:Dell Inc. AW3425DW DD5H274, 3440x1440@175, 1920x0, 1, bitdepth, 10

      misc {
        force_default_wallpaper = 2
      }

      bind = SUPER, right, movetoworkspace, 1
      bind = SUPER, left, movetoworkspace, 2


    '';

    hyprpanelExtraConfig.bar.layouts."*".right = [
      "volume"
      "netstat"
      "clock"
      "systray"
      "notifications"
      "network"
      "bluetooth"
      "battery"
    ];
  };
}
