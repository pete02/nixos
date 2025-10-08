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
      ...
    }@inputs:
    {
      nixpkgs.config.allowUnfree = true;
      nixosConfigurations.talia = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/talia/configuration.nix
          inputs.home-manager.nixosModules.default
        ];
      };
      nixosConfigurations.aria = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          inherit inputs;
          inherit nixpkgsStable;
        };
        modules = [
          ./hosts/aria/configuration.nix
        ];
      };
      nixosConfigurations.raysha = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          inherit inputs;
        };
        modules = [
          ./hosts/raysha/configuration.nix
          inputs.home-manager.nixosModules.default
        ];
      };

    };
}
