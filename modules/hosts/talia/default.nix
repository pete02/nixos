{self, ...}: {
  flake.nixosConfigurations.talia = self.lib.mkHost {
    hostname = "talia";
    system = "x86_64-linux";
    modules = [
      ./_hardware-configuration.nix
      ./_desktops.nix
      ./_configuration.nix
    ];
  };
}
