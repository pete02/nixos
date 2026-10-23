{
  self,
  ...
}: {
  flake.nixosModules.dev = {
    imports = with self.nixosModules; [
      dev-tools
      dev-git
      dev-virtualization
      dev-android
    ];
  };
}
