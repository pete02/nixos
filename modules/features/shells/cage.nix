{...}: {
  # Cage: a Wayland kiosk compositor that runs exactly one fullscreen program.
  # This is only the shell. What it runs, its secrets and the apps around it are
  # decided by the desktop that enables it (see desktops/_alanna.nix).
  flake.nixosModules.shells-cage = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.shells.cage;
  in {
    options.shells.cage = {
      enable = lib.mkEnableOption "cage kiosk session on tty1";

      program = lib.mkOption {
        type = lib.types.str;
        example = lib.literalExpression "lib.getExe pkgs.pegasus-frontend";
        description = "Command cage runs fullscreen. The session restarts if it exits.";
      };

      user = lib.mkOption {
        type = lib.types.str;
        default = config.username;
        description = "User the cage session runs as.";
      };

      extraGroups = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = ["video" "audio" "input"];
        description = "Extra groups for the kiosk user (GPU, sound, controllers).";
      };

      extraArguments = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        # -s: allow VT switching
        # -d: no client-side decorations
        default = ["-s" "-d"];
        description = "Extra command line arguments for cage.";
      };

      environment = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {};
        description = "Environment variables for the cage session.";
      };

      environmentFiles = lib.mkOption {
        type = lib.types.listOf lib.types.path;
        default = [];
        description = ''
          Environment files for the cage unit (read by systemd as root), for
          values that must not end up in the Nix store.
        '';
      };

      restartTriggers = lib.mkOption {
        type = lib.types.listOf lib.types.unspecified;
        default = [];
        description = ''
          Extra values whose change restarts the session on switch, for inputs
          the unit does not reference directly.
        '';
      };
    };

    config = lib.mkIf config.shells.cage.enable {
      hardware.graphics.enable = true;

      users.users.${cfg.user} = {
        isNormalUser = true;
        inherit (cfg) extraGroups;
      };

      services.cage = {
        enable = true;
        inherit (cfg) user program extraArguments environment;
      };

      systemd.services."cage-tty1" = {
        # The nixpkgs cage module sets restartIfChanged = false. For a kiosk we
        # want the opposite: a switch that changes the unit restarts the
        # session by itself, so updates need no reboot or manual intervention.
        restartIfChanged = lib.mkForce true;
        inherit (cfg) restartTriggers;

        serviceConfig = {
          EnvironmentFile = cfg.environmentFiles;
          # Restart cage if the program exits or crashes
          Restart = lib.mkForce "always";
        };
      };
    };
  };
}
