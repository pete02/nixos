{self, inputs, ...}: {
  flake.nixosModules.rayshaConfiguration = {pkgs, lib, config, ...}:{
      config={
        networking.hostName = "raysha";
      };
  };
}