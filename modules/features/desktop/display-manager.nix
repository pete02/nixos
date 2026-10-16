
{ ... }: {
  flake.nixosModules.desktop-display-manager = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.displayManager;
  in {
    options.displayManager = {
      enable = lib.mkEnableOption "the display manager";

      backend = lib.mkOption {
        type = lib.types.enum [
          "greetd"
          "sddm"
        ];
        default = "greetd";
        description = "Display manager backend to use.";
      };

      autoLogin = lib.mkEnableOption "automatic session login";

      user = lib.mkOption {
        type = lib.types.str;
        default = config.username;
        description = "User to log into the graphical session.";
      };

      sessionPackage = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        default = null;
        description = ''
          Package providing the desktop session.
          Used by display managers supporting session packages.
        '';
      };

      sessionName = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = ''
          Display manager session identifier, such as
          plasma-bigscreen-wayland.
        '';
      };

      sessionCommand = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = ''
          Command used to launch the session, including any
          required arguments. Used by greetd.
        '';
      };

      greeterCommand = lib.mkOption {
        type = lib.types.str;
        default = "${pkgs.tuigreet}/bin/tuigreet --time --cmd '${cfg.sessionCommand}'";
        description = "Command used to launch the greetd greeter.";
      };
    };

    config = lib.mkIf cfg.enable (lib.mkMerge [
      {
        assertions = [
          {
            assertion =
              cfg.backend != "greetd"
              || cfg.sessionCommand != "";
            message = ''
              displayManager.sessionCommand must be set when
              using the greetd backend.
            '';
          }
          {
            assertion =
              cfg.backend != "sddm"
              || cfg.sessionName != "";
            message = ''
              displayManager.sessionName must be set when
              using the SDDM backend.
            '';
          }
        ];
      }

      (lib.mkIf (cfg.backend == "greetd") {
        services.greetd = {
          enable = true;

          settings = {
            default_session = {
              command = cfg.greeterCommand;
              user = "greeter";
            };
          } // lib.optionalAttrs cfg.autoLogin {
            initial_session = {
              command = cfg.sessionCommand;
              user = cfg.user;
            };
          };
        };
      })

      (lib.mkIf (cfg.backend == "sddm") {
        services.displayManager = {
          sddm = {
            enable = true;
            wayland.enable = true;
          };

          sessionPackages =
            lib.optional (cfg.sessionPackage != null)
              cfg.sessionPackage;

          defaultSession = cfg.sessionName;

          autoLogin = {
            enable = cfg.autoLogin;
            user = cfg.user;
          };
        };
      })
    ]);
  };
}
