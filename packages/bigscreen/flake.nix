{
  description = "Plasma Bigscreen for NixOS 26.05 (Plasma 6.6)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = {
    self,
    nixpkgs,
  }: let
    systems = ["aarch64-linux" "x86_64-linux"];
    forAllSystems = nixpkgs.lib.genAttrs systems;
  in {
    packages = forAllSystems (system: rec {
      plasma-bigscreen =
        nixpkgs.legacyPackages.${system}.kdePackages.callPackage ./package.nix {};
      default = plasma-bigscreen;
    });

    # Adds pkgs.plasma-bigscreen, built against the consumer's package set.
    overlays.default = final: _prev: {
      plasma-bigscreen = final.kdePackages.callPackage ./package.nix {};
    };

    nixosModules = rec {
      plasma-bigscreen = ./module.nix;
      default = plasma-bigscreen;
    };

    checks = forAllSystems (system: {
      inherit (self.packages.${system}) plasma-bigscreen;
    });
  };
}
