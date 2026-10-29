{self, ...}: {
  flake.nixosConfigurations.alanna = self.lib.mkRpiHost {
    hostname = "alanna";

    modules = [
      ./_configuration.nix
    ];
  };
}
