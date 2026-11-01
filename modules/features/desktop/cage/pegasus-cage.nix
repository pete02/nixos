{self, ...}: {
  flake.nixosModules.desktop-pegasus-cage = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.desktop.pegasus-cage;
    user = config.users.users.${cfg.user};
    tv-ui-app = self.packages.${pkgs.stdenv.hostPlatform.system}.tv-ui-app;

    metadataFile = pkgs.writeText "applications.metadata.pegasus.txt" ''
      collection: Applications
      shortname: apps
      launch: "{file.path}"

      game: Moonlight
      file: ${lib.getExe cfg.moonlightPackage}
      developer: Moonlight Game Streaming Project
      genre: Streaming

      game: TV UI
      file: ${lib.getExe tv-ui-app}
      developer: Local TV UI
      genre: Applications

      game: VacuumTube
      file: ${lib.getExe cfg.vacuumTubePackage}
      developer: VacuumTube
      genre: Video
    '';
  in {
    options.desktop.pegasus-cage = {
      enable = lib.mkEnableOption "Pegasus frontend running in a cage kiosk session";

      tmdbSecret = lib.mkOption {
        type = lib.types.str;
        default = "${config.hostname}/tmdb_api_key";
        example = "aria/tmdb_api_key";
        description = ''
          Name of the SOPS secret containing the TMDB API key for tv-ui.
          It is passed to the cage session as TMDB_API_KEY.
        '';
      };

      user = lib.mkOption {
        type = lib.types.str;
        default = config.username;
        description = "User the cage session (and Pegasus) runs as.";
      };

      package = lib.mkPackageOption pkgs "pegasus-frontend" {};

      moonlightPackage = lib.mkPackageOption pkgs "moonlight-qt" {};

      vacuumTubePackage = lib.mkOption {
        type = lib.types.package;
        default = self.packages.${pkgs.stdenv.hostPlatform.system}.vacuum-tube;
        description = "VacuumTube package to launch from Pegasus.";
      };

      extraGroups = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = ["video" "audio" "input" "uinput"];
        description = "Extra groups for the kiosk user (GPU, sound, controllers, tv-ui pointer).";
      };

      extraEnvironment = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {};
        description = "Extra environment variables for the cage session.";
      };
    };

    config = lib.mkIf cfg.enable {
      environment.systemPackages = [
        tv-ui-app
        cfg.moonlightPackage
        cfg.vacuumTubePackage
      ];

      # Read by systemd as root, so no owner is needed.
      sops.secrets.${cfg.tmdbSecret} = {};

      sops.templates."tv-ui.env".content = ''
        TMDB_API_KEY=${config.sops.placeholder.${cfg.tmdbSecret}}
      '';

      desktop.hdmi-cec.enable = true;

      # tv-ui's pointer websocket creates a uinput device
      hardware.uinput.enable = true;

      # Pegasus application entries
      systemd.tmpfiles.rules = [
        "d ${user.home}/.config/pegasus-frontend/metafiles 0755 ${cfg.user} ${user.group} - -"
        "L+ ${user.home}/.config/pegasus-frontend/metafiles/applications.metadata.pegasus.txt - - - - ${metadataFile}"
      ];

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

        environment =
          {
            QT_QPA_PLATFORM = "wayland";
          }
          // cfg.extraEnvironment;
      };

      systemd.services."cage-tty1" = {
        # The nixpkgs cage module sets restartIfChanged = false. For a kiosk we
        # want the opposite: a switch that changes the unit restarts the
        # session by itself, so updates need no reboot or manual intervention.
        restartIfChanged = lib.mkForce true;

        # The unit doesn't reference the launcher entries (they're symlinked in
        # via tmpfiles), so restart when they change, i.e. when tv-ui,
        # Moonlight or VacuumTube get a new store path.
        restartTriggers = [metadataFile];

        serviceConfig = {
          # TMDB_API_KEY reaches Pegasus and everything it launches
          EnvironmentFile = [config.sops.templates."tv-ui.env".path];
          # Restart Cage if Pegasus exits or crashes
          Restart = lib.mkForce "always";
        };
      };

      # Sound
      services.pipewire = {
        enable = lib.mkDefault true;
        alsa.enable = lib.mkDefault true;
        pulse.enable = lib.mkDefault true;
      };
    };
  };
}
