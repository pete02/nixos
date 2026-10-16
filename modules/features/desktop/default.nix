{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.desktop = {
    imports = with self.nixosModules; [
      desktop-hyprland
      desktop-plasma-bigscreen
      desktop-wayle
      desktop-selection
      desktop-services
      desktop-display-manager
    ];
  };
}
