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
    { self, nixpkgs, ... }@inputs:
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
        modules = [
          ./hosts/raysha/configuration.nix
          inputs.home-manager.nixosModules.default
        ];
      };

      nixpkgs.overlays = [
        (final: prev: {
          hyprland-qt-support = prev.hyprland-qt-support.overrideAttrs (old: {
            nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ final.qt6.wrapQtAppsHook ];
          });
        })
      ];

    };
}
