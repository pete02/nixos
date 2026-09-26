{
  self,
  inputs,
  ...
}: {
  flake.nixosConfigurations.raysha = self.lib.mkHost {
    hostname = "raysha";
    system = "x86_64-linux";

    modules = [
      self.nixosModules.rayshaHardware
      self.nixosModules.rayshaConfiguration
      self.nixosModules.connectivity
      self.nixosModules.services
      self.nixosModules.management
      self.nixosModules.nixBuilders
    ];
  };
}
