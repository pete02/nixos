{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.gaming = {
    imports = [
      self.nixosModules.gaming-steam
      self.nixosModules.gaming-performance
      self.nixosModules.gaming-compatibility
      self.nixosModules.gaming-sunshine
      self.nixosModules.gaming-rpcs3
      self.nixosModules.gaming-graphics
    ];
  };
}
