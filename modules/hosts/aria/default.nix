{
  self,
  inputs,
  ...
}: {
  flake.nixosConfigurations.aria = self.lib.mkHost {
    hostname = "aria";
    system = "x86_64-linux";

    modules = [
      self.nixosModules.ariaHardware
      self.nixosModules.ariaConfiguration
      self.nixosModules.connectivity
      self.nixosModules.services
      self.nixosModules.management
      self.nixosModules.nixBuilders
    ];
  };
}
