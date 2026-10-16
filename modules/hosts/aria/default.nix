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
    ];
  };
}
