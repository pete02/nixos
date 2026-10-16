{
  self,
  inputs,
  ...
}: {
  flake.nixosConfigurations.talia = self.lib.mkHost {
    hostname = "talia";
    system = "x86_64-linux";
    modules = [
      ./_hardware-configuration.nix
      ./_configuration.nix
      self.nixosModules.hyprland
    ];
  };
}
