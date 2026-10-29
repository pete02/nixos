{self,inputs, ...}: {
  flake.nixosConfigurations.alanna = self.lib.mkRpiHost {
    hostname = "alanna";
    system = "aarch64-linux";
    modules = [
      ./_configuration.nix
      ./_hardware-configuration.nix
    ];
    extraArgs = {inherit (inputs) nixos-raspberrypi;};
  };
}
