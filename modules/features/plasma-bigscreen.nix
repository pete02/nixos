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
    };
  in {
    options = {
      username = lib.mkOption {
        type = lib.types.str;
      };
    };

    config = {
      environment.systemPackages = [
        plasmaBigscreenPkg
      ];

      xdg.portal = {
        enable = true;
        extraPortals = [
          pkgs.kdePackages.xdg-desktop-portal-kde
        ];
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
