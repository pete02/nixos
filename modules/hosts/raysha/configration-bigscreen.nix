{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.raysha-bigscreenConfiguration = {
    pkgs,
    lib,
    config,
    ...
  }: {
    imports = [
      self.nixosModules.plasmaBigscreen
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

    users.users.pete.extraGroups = ["adbusers"];
  };
}
