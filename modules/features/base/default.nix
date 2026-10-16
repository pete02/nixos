{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.base = {
    imports = with self.nixosModules; [
      base-apps
      base-settings
    ];
  };
}
