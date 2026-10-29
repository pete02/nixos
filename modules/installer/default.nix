# Installer images + install tooling (x86 ISO, Pi 3 / Pi 5 SD images).
# Everything except this file is prefixed with `_` so import-tree ignores it.
{
  inputs,
  self,
  lib,
  ...
}: let
  settings = import ./_settings.nix;
in {
  flake.nixosConfigurations = {
    # Target system the ISO installs (generic UEFI x86_64).
    x86 = inputs.nixpkgs.lib.nixosSystem {
      specialArgs = {inherit settings self;};
      modules = [./_hosts/x86.nix];
    };

    rpi3 = inputs.nixpkgs.lib.nixosSystem {
      specialArgs = {inherit settings self;};
      modules = [./_hosts/rpi3.nix];
    };

    rpi5 = inputs.nixos-raspberrypi.lib.nixosSystem {
      specialArgs = {
        inherit settings self;
        inherit (inputs) nixos-raspberrypi;
      };
      modules = [./_hosts/rpi5.nix];
    };
  };

  perSystem = {
    self',
    system,
    ...
  }: let
    pkgs = inputs.nixpkgs.legacyPackages.${system};
  in {
    packages = {
      installer = pkgs.callPackage ./_package.nix {bundledFlake = self;};
      sd-rpi3 = self.nixosConfigurations.rpi3.config.system.build.sdImage;
      sd-rpi5 = self.nixosConfigurations.rpi5.config.system.build.sdImage;
    };
    apps.installer = {
      type = "app";
      program = "${self'.packages.installer}/bin/nixos-installer";
    };
  };
}
