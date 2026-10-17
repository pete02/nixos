{
  self,
  inputs,
  lib,
  ...
}: let
  # Facts about each machine that other modules read (ssh, builders).
  # Adding a machine: add it here, and add modules/hosts/<name>/.
  rawHosts = {
    aria.buildServer = true;
    raysha.buildServer = true;
    talia.sshServer = true;
  };

  hosts = lib.mapAttrs (_: host:
    host // {sshServer = host.sshServer or false || host.buildServer or false;})
  rawHosts;

  # Imported into EVERY host. Each of these must be harmless when its
  # options are off (everything inside mkIf), or be wanted on all hosts.
  # Once every feature is gated, replace with:
  #   builtins.attrValues self.nixosModules
  featureModules = with self.nixosModules; [
    sops
    dev
    connectivity
    nixbuilder
    base
    ssh
    samba-timelock
    healthcheck
    power
    samba
    hardware
    bitwarden-backup
    nixos-management
    gaming
    timelock
    desktop
  ];
in {
  flake.lib.hosts = hosts;

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
        featureModules
        ++ modules
        ++ [
          {
            inherit hostname;
            # mkDefault so a host can still override these.
            ssh.server = lib.mkDefault (hosts.${hostname}.sshServer or false);
            nixbuilder.buildServer = lib.mkDefault (hosts.${hostname}.buildServer or false);
          }
        ];
    };
}
