
{ ... }: {
  flake.nixosModules.gaming-performance = { lib, pkgs, config, ... }: {
    options.gaming.performance =
      lib.mkEnableOption "Gaming performance tools";

    config = lib.mkIf config.gaming.performance {
      programs.gamescope = {
        enable = true;
        capSysNice = false;
      };

      programs.gamemode.enable = true;

      environment.systemPackages = with pkgs; [
        mangohud
      ];

      services.seatd.enable = false;
    };
  };
}
