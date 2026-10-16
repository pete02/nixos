{
  self,
  inputs,
  ...
}: {
  flake.nixosConfigurations.talia = self.lib.mkHost {
    hostname = "talia";
    system = "x86_64-linux";
    modules = [
      self.nixosModules.taliaHardware
      self.nixosModules.taliaConfiguration
      self.nixosModules.connectivity
      self.nixosModules.services
      self.nixosModules.nixBuilders
      self.nixosModules.management
      self.nixosModules.ssh
      self.nixosModules.base
    ];
  };
}
