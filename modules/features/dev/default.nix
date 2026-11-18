{self, ...}: {
  flake.nixosModules.dev = {
    imports = with self.nixosModules; [
      dev-tools
      dev-virtualization
      dev-android
    ];
  };
}
