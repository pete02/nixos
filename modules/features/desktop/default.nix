{
  self,
  ...
}: {
  flake.nixosModules.desktop = {
    imports = with self.nixosModules; [
      desktop-hyprland
      desktop-bigscreen
      desktop-wayle
      desktop-selection
      desktop-services
      desktop-displaymanager
    ];
  };
}
