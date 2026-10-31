
{self, ...}: {
  flake.nixosModules.desktop-pegasus-cage = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.desktop.pegasus-cage;

    tv-ui = self.packages.${pkgs.stdenv.hostPlatform.system}.tv-ui;
  in {
    options.desktop.pegasus-cage = {
      enable = lib.mkEnableOption "Pegasus frontend running in a cage kiosk session";
      tmdb_api_key=lib.mkOption {
        type = lib.types.str;
        default = "${config.hostname}/tmdb_api_key";
        example = "restic/aria";
        description = ''
          Name of the SOPS secret containing the Restic repository password.
          The module declares the secret and grants the backup user read access.
        '';
      };
      user = lib.mkOption {
        type = lib.types.str;
        default = config.username;
        description = "User the cage session (and Pegasus) runs as.";
      };

      package = lib.mkPackageOption pkgs "pegasus-frontend" {};

      moonlightPackage = lib.mkPackageOption pkgs "moonlight-qt" {};

      vacuumTubePackage = lib.mkPackageOption pkgs "vacuum-tube" {};

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
      environment.systemPackages = [
        tv-ui
        cfg.moonlightPackage
        cfg.vacuumTubePackage
      ];

      # Pegasus application entries
      environment.etc."xdg/pegasus-frontend/metafiles/applications.metadata.pegasus.txt".text = ''
        collection: Applications
        shortname: apps
        launch: "{file.path}"

        game: Moonlight
        file: ${lib.getExe cfg.moonlightPackage}
        developer: Moonlight Game Streaming Project
        genre: Streaming

        game: VacuumTube
        file: ${lib.getExe cfg.vacuumTubePackage}
        developer: VacuumTube
        genre: Video
      '';

      users.users.${cfg.user} = {
        isNormalUser = true;
        inherit (cfg) extraGroups;
      };

      hardware.graphics.enable = true;

      services.cage = {
        enable = true;
        user = cfg.user;
        program = lib.getExe cfg.package;

        # -s: allow VT switching
        # -d: no client-side decorations
        extraArguments = ["-s" "-d"];

        environment = {
          QT_QPA_PLATFORM = "wayland";
          TMDB_API_KEY = config.sops.secrets.${cfg.tmdb_api_key};
        } // cfg.extraEnvironment;
      };

      # Restart Cage if Pegasus exits or crashes
      systemd.services."cage-tty1".serviceConfig.Restart =
        lib.mkForce "always";

      # Sound
      services.pipewire = {
        enable = lib.mkDefault true;
        alsa.enable = lib.mkDefault true;
        pulse.enable = lib.mkDefault true;
      };
    };
  };
}
