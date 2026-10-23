{self, ...}: {
  flake.nixosConfigurations.talia = self.lib.mkHost {
    hostname = "talia";
    system = "x86_64-linux";
    modules = [
      ./_hardware-configuration.nix
      ./_hyprland.nix
      ./_configuration.nix
    ];
  };
}
