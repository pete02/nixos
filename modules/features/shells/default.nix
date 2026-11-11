{self, ...}: {
  flake.nixosModules.shells = {
    imports = with self.nixosModules; [
      shells-hyprland
      shells-bigscreen
      shells-wayle
      shells-selection
      shells-services
      shells-displaymanager
      shells-pegasus-cage
      shells-hdmi-cec
      shells-streaming
    ];
  };
}
