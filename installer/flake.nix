{
  description = "NixOS installer images + install tooling for x86_64, Raspberry Pi 3 and Raspberry Pi 5";

  # Pi 5 kernel/firmware come from nvmd/nixos-raspberrypi, which ships a binary cache.
  # Verify the key against that repo's README before trusting it.
  nixConfig = {
    extra-substituters = [ "https://nixos-raspberrypi.cachix.org" ];
    extra-trusted-public-keys = [
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
    ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    # Deliberately NOT following our nixpkgs: it pins its own to match its cache.
    nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi/main";
  };

  outputs = { self, nixpkgs, nixos-raspberrypi, ... }:
    let
      settings = import ./settings.nix;
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAll = f: nixpkgs.lib.genAttrs systems f;
      installerFor = pkgs: pkgs.callPackage ./pkgs/installer.nix { bundledFlake = self; };
    in
    {
      nixosConfigurations = {
        # --- systems you actually run -------------------------------------
        x86 = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit settings; };
          modules = [ ./hosts/x86 ];
        };
        rpi3 = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit settings; };
          modules = [ ./hosts/rpi3 ];
        };
        rpi5 = nixos-raspberrypi.lib.nixosSystem {
          specialArgs = { inherit settings nixos-raspberrypi; };
          modules = [ ./hosts/rpi5 ];
        };

        # --- live installer for x86 ----------------------------------------
        iso-x86 = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit settings self; };
          modules = [ ./hosts/iso-x86 ];
        };
      };

      packages = forAll (system:
        let pkgs = nixpkgs.legacyPackages.${system}; in
        rec {
          installer = installerFor pkgs;
          default = installer;
          iso-x86 = self.nixosConfigurations.iso-x86.config.system.build.isoImage;
          sd-rpi3 = self.nixosConfigurations.rpi3.config.system.build.sdImage;
          sd-rpi5 = self.nixosConfigurations.rpi5.config.system.build.sdImage;
        });

      apps = forAll (system: rec {
        installer = {
          type = "app";
          program = "${self.packages.${system}.installer}/bin/nixos-installer";
        };
        default = installer;
      });

      devShells = forAll (system:
        let pkgs = nixpkgs.legacyPackages.${system}; in
        { default = pkgs.mkShell { packages = [ self.packages.${system}.installer pkgs.git ]; }; });
    };
}
