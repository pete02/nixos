{

  description = "A very basic flake";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    hyprland.url = "github:hyprwm/Hyprland";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      inputs,
      ...
    }:
    let
      overlay = final: prev: {
        gamescope = prev.gamescope.overrideAttrs (oldAttrs: rec {
          version = "3.16.17";
          src = prev.fetchFromGitHub {
            owner = "ValveSoftware";
            repo = "gamescope";
            rev = "refs/tags/${version}";
            fetchSubmodules = true;
            hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
          };
        });
      };
    in
    {

      nixosConfigurations.talia = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/talia/configuration.nix
          inputs.home-manager.nixosModules.default
        ];
      };

      nixosConfigurations.raysha = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        nixpkgs.overlays = [ overlay ];
        modules = [
          ./hosts/raysha/configuration.nix
          inputs.home-manager.nixosModules.default
        ];
      };

    };
}
