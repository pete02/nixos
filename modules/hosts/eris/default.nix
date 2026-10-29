{self,inputs, ...}: {
  flake.nixosConfigurations.eris = self.lib.mkRpiHost {
    hostname = "eris";
    system = "aarch64-linux";
    modules = [
      ./_configuration.nix
      ./_hardware-configuration.nix
    ];
    extraArgs = {inherit (inputs) nixos-raspberrypi;};
  };
}
