{self, inputs, ...}: {
  flake.nixosModules.rayshaConfiguration = {pkgs, lib, config, ...}:{
      config={
        networking.hostName = "raysha";
        modules.system.user.name = "pete";
      };
      imports=[
        self.nixosModules.hyprland
      ];
  };
}