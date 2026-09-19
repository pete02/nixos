{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";
    wrappers.url = "github:Lassulus/wrappers";
    wrapper-modules.url = "github:BirdeeHub/nix-wrapper-modules";
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel";
    sops-nix.url = "github:Mic92/sops-nix";
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} (
      {self, ...}: {
        imports = [(inputs.import-tree ./modules)];
        perSystem = {pkgs, ...}: {
          formatter = pkgs.alejandra;
        };
        flake.lib.mkHost = {
          system,
          modules,
          extraArgs ? {},
        }:
          inputs.nixpkgs.lib.nixosSystem {
            inherit system;
            specialArgs =
              {
                inherit inputs self;
                selfPkgs = self.packages.${system};
              }
              // extraArgs;
            inherit modules;
          };
      }
    );
}
