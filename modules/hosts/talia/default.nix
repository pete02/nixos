{
  self,
  inputs,
  ...
}: {
  flake.nixosConfigurations.talia = self.lib.mkHost {
    system = "x86_64-linux";
    modules = [
      self.nixosModules.taliaHardware
      self.nixosModules.taliaConfiguration
      self.nixosModules.connectivity
      self.nixosModules.services
      self.nixosModules.management
    ];
  };
    flake.nixosConfigurations.talia-bigscreen = self.lib.mkHost {
    system = "x86_64-linux";
    modules = [
      self.nixosModules.taliaHardware
      self.nixosModules.taliaConfigurationBigscreen
      self.nixosModules.connectivity
      self.nixosModules.services
      self.nixosModules.management
    ];
  };
}
