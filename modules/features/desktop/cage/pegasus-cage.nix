{...}: {
  flake.nixosModules.pegasus-cage = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.fleet.pegasus-cage;
  in {
    options.fleet.pegasus-cage = {
      enable = lib.mkEnableOption "Pegasus frontend running in a cage kiosk session";

      user = lib.mkOption {
        type = lib.types.str;
        default = "pegasus";
        description = "User the cage session (and Pegasus) runs as.";
      };

      package = lib.mkPackageOption pkgs "pegasus-frontend" {};

      extraGroups = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = ["video" "audio" "input"];
        description = "Extra groups for the kiosk user (GPU, sound, controllers).";
      };

      extraEnvironment = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {};
        description = "Extra environment variables for the cage session.";
      };
    };

    config = lib.mkIf cfg.enable {
      users.users.${cfg.user} = {
        isNormalUser = true;
        inherit (cfg) extraGroups;
      };

      hardware.graphics.enable = true;

      services.cage = {
        enable = true;
        user = cfg.user;
        program = lib.getExe cfg.package;
        # -s: allow VT switching (handy for debugging), -d: no client-side decorations
        extraArguments = ["-s" "-d"];
        environment =
          {
            QT_QPA_PLATFORM = "wayland";
          }
          // cfg.extraEnvironment;
      };

      # Make sure the kiosk comes back if Pegasus is quit/crashes
      systemd.services."cage-tty1".serviceConfig.Restart = lib.mkForce "always";

      # Sound for games
      services.pipewire = {
        enable = lib.mkDefault true;
        alsa.enable = lib.mkDefault true;
        pulse.enable = lib.mkDefault true;
      };
    };
  };
}
