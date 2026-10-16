{self, ...}: {
  flake.nixosConfigurations.raysha = self.lib.mkHost {
    hostname = "raysha";
    system = "x86_64-linux";

    modules = [
      ./_hardware.nix
      ./_configuration.nix
    ];
  };
}