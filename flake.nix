{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-26.05";
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

        flake.lib.hosts = let
          rawHosts = {
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
                selfPkgs = self.packages.${system};
              }
              // extraArgs;

            modules =
              modules
              ++ [
                {
                  nix.settings.substituters = [
                    "https://cache.nixos.org/"
                  ];

                  inherit hostname;
                  services.sshServer = self.lib.hosts.${hostname}.sshServer or false;
                  nixbuilders.buildServer = self.lib.hosts.${hostname}.buildServer or false;
                }
              ];
          };
      }
    );
}
