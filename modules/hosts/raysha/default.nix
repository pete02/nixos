{
  self,
  inputs,
  ...
}: {
  flake.nixosConfigurations.raysha = self.lib.mkHost {
    system = "x86_64-linux";

    modules = [
      self.nixosModules.rayshaHardware
      self.nixosModules.rayshaConfiguration
      self.nixosModules.connectivity
      self.nixosModules.services
      self.nixosModules.management
    ];
  };

  flake.nixosConfigurations.raysha-bigscreen = self.lib.mkHost {
    system = "x86_64-linux";

    modules = [
      self.nixosModules.rayshaHardware
      self.nixosModules.raysha-bigscreenConfiguration
      self.nixosModules.connectivity
      self.nixosModules.services
      self.nixosModules.management
    ];
  };
}
