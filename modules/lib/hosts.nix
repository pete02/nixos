{
  self,
  inputs,
  lib,
  ...
}: let
  rawHosts = {
    aria.buildServer = true;
    raysha.buildServer = true;
    talia.sshServer = true;
    rpi-test.rpi = true;
  };

  hosts = lib.mapAttrs (_: host:
    host
    // {
      sshServer = host.sshServer or false || host.buildServer or false;
      rpi = host.rpi or false;
    })
  rawHosts;

  # Unchanged: every host, Pi included, gets all of these.
  featureModules = with self.nixosModules; [
    sops dev connectivity nixbuilder base ssh samba-timelock healthcheck
    power samba hardware bitwarden-backup nixos-management gaming timelock desktop
  ];

  # Added only for Pi hosts, on top of featureModules.
  rpiModules = [
    "${inputs.nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
    self.nixosModules.rpi
  ];

  mkHost = {
    hostname,
    system,
    modules,
    extraArgs ? {},
    rpi ? false,
    nixosSystem ? inputs.nixpkgs.lib.nixosSystem,
  }:
    # The table and the constructor must agree, in both directions.
    assert lib.assertMsg ((hosts.${hostname}.rpi or false) == rpi)
    "${hostname}: `rpi` in rawHosts must match whether it is built with mkRpiHost";
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
              ssh.server.enable = lib.mkDefault (hosts.${hostname}.sshServer or false);
              nixbuilder.buildServer = lib.mkDefault (hosts.${hostname}.buildServer or false);
            }
          ];
      };

  mkRpiHost = {system ? "aarch64-linux", ...} @ args:
    assert lib.assertMsg (system == "aarch64-linux")
    "mkRpiHost: Pi hosts must be aarch64-linux, got ${system}";
      mkHost (args
        // {
          inherit system;
          rpi = true;
          modules = rpiModules ++ args.modules;
        });
in {
  flake.lib.hosts = hosts;
  flake.lib.rpiHosts = lib.filterAttrs (_: h: h.rpi) hosts;
  flake.lib.mkHost = mkHost;
  flake.lib.mkRpiHost = mkRpiHost;
}