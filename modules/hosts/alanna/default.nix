{
  self,
  inputs,
  ...
}: {
  flake.nixosConfigurations.alanna = self.lib.mkHost {
    hostname = "alanna";
    system = "aarch64-linux"; # was x86_64-linux
    nixosSystem = inputs.nixos-raspberrypi.lib.nixosSystem;

    modules = [
      self.nixosModules.sops
      self.nixosModules.alannaHardware
      self.nixosModules.alannaConfiguration
      self.nixosModules.connectivity
      self.nixosModules.services
      self.nixosModules.management
      self.nixosModules.common
    ];
  };
}
