{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    hyprland.url = "github:hyprwm/Hyprland";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel";
  };

  outputs =
    { self, nixpkgs, ... }@inputs:
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
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/aria/configuration.nix
        ];
      };

      nixosConfigurations.raysha = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        specialArgs = { inherit inputs; };

        modules = [
          ./hosts/raysha/configuration.nix
          inputs.home-manager.nixosModules.default
          (
            {
              pkgs,
              lib,
              config,
              ...
            }:
            let
              cachyosOverlay = final: prev: {
                # Replace the kernel derivation in the package set
                linuxPackages = prev.linuxPackages // {
                  kernel = inputs.nix-cachyos-kernel.packages.x86_64-linux.linux-cachyos-latest-zen4;
                };
              };
              pkgsWithOverlay = import inputs.nixpkgs {
                system = "x86_64-linux";
                overlays = [ cachyosOverlay ];
              };
            in
            {
              nixpkgs.overlays = [ cachyosOverlay ];
              config.allowUnfree = true;
              config.allowUnfreePredicate =
                pkg:
                builtins.elem (lib.getName pkg) [
                  "nvidia-x11"
                ];
              nix.settings.substituters = [ "https://attic.xuyh0120.win/lantian" ];
              nix.settings.trusted-public-keys = [ "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc=" ];

              # Use the NixOS kernel package set (with overlay applied)
              boot.kernelPackages = pkgsWithOverlay.linuxPackages;
            }
          )
        ];
      };
    };
}
