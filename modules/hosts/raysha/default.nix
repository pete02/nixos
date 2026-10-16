{self, ...}: {
  flake.nixosConfigurations.raysha = self.lib.mkHost {
    hostname = "raysha";
    system = "x86_64-linux";

    modules = [
      ./_hardware.nix
      ./_configuration.nix
      # Not yet enable-gated, so still opted in per host. Delete each line
      # once the module is converted and added to featureModules.
      self.nixosModules.hyprland
      self.nixosModules.gaming
    ];
  };
}