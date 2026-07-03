{ self, inputs, ... }: {
  flake.nixosConfigurations.raysha = self.lib.mkHost {
    system = "x86_64-linux";
    modules = [
      self.nixosModules.ariaHardware
      self.nixosModules.ariaConfiguration
      self.nixosModules.connectivity
      self.nixosModules.services
      self.nixosModules.management
    ];
  };
}
