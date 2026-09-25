{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
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

        flake.lib.hosts = {
          alanna = {
            sshServer = true;
          };
          aria = {
            sshServer = true;
          };

          raysha = {
            sshServer = true;
          };

          talia = {
            sshServer = true;
          };
        };

        flake.lib.mkHost = {
          hostname,
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
            modules =
              modules
              ++ [
                {
                  inherit hostname;
                  services.sshServer =
                    self.lib.hosts.${hostname}.sshServer or false;
                }
              ];
          };
      }
    );
}
