{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-raspberrypi = {
      url = "github:nvmd/nixos-raspberrypi/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";
    wrappers.url = "github:Lassulus/wrappers";
    wrapper-modules.url = "github:BirdeeHub/nix-wrapper-modules";
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel";
    sops-nix.url = "github:Mic92/sops-nix";
  };

  nixConfig = {
    extra-substituters = [
      "https://nixos-raspberrypi.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
    ];
  };
  outputs = inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} (
      {self, ...}: {
        imports = [(inputs.import-tree ./modules)];
        perSystem = {pkgs, ...}: {
          formatter = pkgs.alejandra;
        };

        flake.lib.hosts = let
          rawHosts = {
            alanna = {
              sshServer = true;
            };
            aria = {
              buildServer = true;
            };
            raysha = {
              buildServer = true;
            };

            talia = {
              sshServer = true;
            };
          };
        in
          builtins.mapAttrs (_: host:
            host // {sshServer = host.sshServer or false || host.buildServer or false;})
          rawHosts;

        flake.lib.mkHost = {
          hostname,
          system,
          modules,
          extraArgs ? {},
          nixosSystem ? inputs.nixpkgs.lib.nixosSystem,
        }:
          nixosSystem {
            inherit system;

            specialArgs =
              {
                inherit inputs self system;
                inherit (inputs) nixos-raspberrypi;
                selfPkgs = self.packages.${system};
              }
              // extraArgs;

            modules =
              modules
              ++ [
                {
                  inherit hostname;
                  services.sshServer = self.lib.hosts.${hostname}.sshServer or false;
                }
              ];
          };
      }
    );
}
