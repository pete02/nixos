{
  inputs,
  self,
  lib,
  ...
}: let
  settings = import ./_settings.nix;
in {
  flake.nixosConfigurations = {
    # The actual ISO installer image configuration
    iso = inputs.nixpkgs.lib.nixosSystem {
      specialArgs = {inherit settings self;};
      modules = [
        "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
        ./_hosts/iso-x86.nix # Or wherever your ISO-specific module lives
      ];
    };

    # Target system the ISO installs onto your NVMe
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
    packages =
      {
        installer = pkgs.callPackage ./_package.nix {bundledFlake = self;};
        sd-rpi3 = self.nixosConfigurations.rpi3.config.system.build.sdImage;
        sd-rpi5 = self.nixosConfigurations.rpi5.config.system.build.sdImage;
      }
      // lib.optionalAttrs (system == "x86_64-linux") {
        iso = self.nixosConfigurations.iso.config.system.build.isoImage; # Points to the ISO config!
      };

    apps.installer = {
      type = "app";
      program = "${self'.packages.installer}/bin/nixos-installer";
    };
  };
}
