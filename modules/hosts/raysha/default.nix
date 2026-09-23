{
  self,
  inputs,
  ...
}: {
  flake.nixosConfigurations.raysha = self.lib.mkHost {
    system = "x86_64-linux";
    modules = [
      self.nixosModules.rayshaHardware
      self.nixosModules.rayshaConfiguration # Pääjärjestelmän konfiguraatio
      self.nixosModules.connectivity
      self.nixosModules.services
      self.nixosModules.management

      # Erikoistumisen määrittely
      ({pkgs, ...}: {
        specialisation.bigscreen.configuration = {
          # 1. Poistetaan pääjärjestelmän konfiguraatio käytöstä tässä erikoistumisessa
          disabledModules = [self.nixosModules.rayshaConfiguration];

          # 2. Otetaan sen sijaan käyttöön bigscreen-konfiguraatio
          imports = [self.nixosModules.raysha-bigscreenConfiguration];
        };
      })
    ];
  };
}
