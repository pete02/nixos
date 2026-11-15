
{
  description = "Official Raspberry Pi build of Moonlight Qt, packaged for NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
  };

  outputs = inputs @ { flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "aarch64-linux" ];

      perSystem = { pkgs, ... }: {
        packages.moonlight-qt-rpi =
          pkgs.callPackage ./moonlight-qt-rpi.nix {};

        packages.default = pkgs.callPackage
          ./moonlight-qt-rpi.nix {};
      };
    };
}
