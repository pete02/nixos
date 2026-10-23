{self, ...}: {
  flake.nixosConfigurations.aria = self.lib.mkHost {
    hostname = "aria";
    system = "x86_64-linux";

    modules = [
      ./_configuration.nix
      ./_hardware-configuration.nix
      ./_hyprland.nix
    ];
  };
}
