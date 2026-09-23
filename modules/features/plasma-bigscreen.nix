{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.plasmaBigscreen = {
    config,
    lib,
    pkgs,
    ...
  }: let
    plasmaBigscreenPkg = self.mkPlasmaBigscreenPkg {
      inherit pkgs;
      extraPackages = config.plasmaBigscreenExtraPackages;
    };
  in {
    options = {
      username = lib.mkOption {
        type = lib.types.str;
      };

      plasmaBigscreenExtraPackages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [];
        description = "Additional packages included in the Plasma Bigscreen environment.";
      };
    };

    config = {
      environment.systemPackages = [
        plasmaBigscreenPkg
      ];

      xdg.portal = {
        enable = true;
        configPackages = [
          pkgs.kdePackages.plasma-bigscreen
        ];
      };

      services.displayManager = {
        defaultSession = "plasma-bigscreen-wayland";
        sessionPackages = [
          pkgs.kdePackages.plasma-bigscreen
        ];

        sddm = {
          enable = true;
          theme = "breeze";
          wayland.enable = true;
          enableHidpi = true;
        };
      };

      services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
        jack.enable = true;
      };

      security.rtkit.enable = true;

      services.upower.enable = true;
    };
  };
}