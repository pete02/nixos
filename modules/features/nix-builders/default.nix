{self, ...}: {
  flake.nixosModules.nixBuilders = {
    config,
    lib,
    pkgs,
    ...
  }: {
    options = {
      nixbuilders = {
        usesBuilders = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
        buildServer = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
      };
    };
    config = lib.mkMerge [
      (lib.mkIf (config.nixbuilders.usesBuilders or false) {
        nix.distributedBuilds = true;
        nix.settings.builders-use-substitutes = true;

        nix.buildMachines =
          builtins.map (hostname: {
            hostName = hostname;
            systems = ["x86_64-linux" "aarch64-linux"];
            protocol = "ssh-ng";
            maxJobs = 8;
            speedFactor = 1;
            supportedFeatures = ["nixos-test" "benchmark" "big-parallel" "kvm"];
            mandatoryFeatures = [];
            # deliberately no sshUser / sshKey here — ssh resolves those
            # from the "Host ${hostname}" alias already in /etc/ssh/ssh_config
            # (HostName, IdentityFile, User all come from there), same as
            # your interactive `ssh aria` already does.
          })
          (builtins.attrNames (lib.filterAttrs (_: host: host.buildServer or false) self.lib.hosts));
      })

      (lib.mkIf (config.nixbuilders.buildServer or false) {
        boot.binfmt.emulatedSystems = ["aarch64-linux"];
      })
    ];
  };
}
