{

  description = "A very basic flake";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    nixpkgsStable.url = "github:nixos/nixpkgs/nixos-25.05";
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
      nixpkgsStable,
      home-manager,
      ...
    }:
    let
      overlay = final: prev: {
        vulkan-tools = nixpkgsStable.vulkan-tools;
      };
    in
    {
      nixosConfigurations.talia = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./hosts/talia/configuration.nix
          home-manager.nixosModules.default
        ];
      };

      nixosConfigurations.raysha = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./hosts/raysha/configuration.nix
          home-manager.nixosModules.default
        ];
        nixpkgs.overlays = [
          overlay
        ];
      };

    };
}
