{self, ...}: {
  flake.nixosConfigurations.eris = self.lib.mkRpiHost {
    hostname = "eris";
    system = "aarch64-linux";
    modules = [
      ./_configuration.nix
      ./_hardware-configuration.nix
    ];
  };
}
