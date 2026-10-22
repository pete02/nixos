{self, ...}: {
  flake.nixosConfigurations.eris = self.lib.mkRpiHost {
    hostname = "eris";

    modules = [
      ./_configuration.nix
      ./_hardware-configuration.nix
    ];
  };
}
