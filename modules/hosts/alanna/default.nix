{self, ...}: {
  flake.nixosConfigurations.eris = self.lib.mkRpiHost {
    hostname = "alanna";

    modules = [
      ./_configuration.nix
    ];
  };
}
