{self, inputs, ...}: {
  flake.nixosConfigurations.raysha = inputs.nixpkgs.lib.nixosSystem{
    modules=[
      self.nixosModules.rayshaHardware
      self.nixosModules.rayshaConfiguration
    ];
  };
}