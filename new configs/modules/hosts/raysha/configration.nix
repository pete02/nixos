{self, inputs, ...}: {
  flake.nixosModules.rayshaConfiguration = {pkgs, lib, config, ...}:{
      username="pete";
      imports=[
        self.nixosModules.hyprland
      ];
  };
}