{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.taliaConfigurationBigscreen = {
    pkgs,
    lib,
    config,
    ...
  }: {
    imports = [
      self.nixosModules.plasmaBigscreen
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
      gitClient=true;
      ld = true;
    };

    common-tools.books = true;
    common-tools.school = true;

    services = {
      cleaner = true;
      mDNS=true;
      sambaClient = true;
    };
  };
}
