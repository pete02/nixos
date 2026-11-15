
{
  description = "Official Raspberry Pi build of Moonlight Qt, packaged for NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-ffmpeg5.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
  };

  outputs = inputs @ { flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "aarch64-linux" ];

      perSystem = { pkgs, system, ... }: {
        packages.moonlight-qt-rpi =
          pkgs.callPackage ./moonlight-qt-rpi.nix {
            ffmpeg5 = inputs.nixpkgs-ffmpeg5.legacyPackages.${system}.ffmpeg_5;
          };

        packages.default = pkgs.callPackage
          ./moonlight-qt-rpi.nix {
            ffmpeg5 = inputs.nixpkgs-ffmpeg5.legacyPackages.${system}.ffmpeg_5;
          };
      };
    };
}
