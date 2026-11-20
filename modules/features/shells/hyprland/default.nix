{
  self,
  inputs,
  ...
}: let
  baseConfig = builtins.readFile ./base.lua;

  mkHyprlandPkg = {
    pkgs,
    extraConfig ? "",
  }: let
    configFile = pkgs.writeText "hyprland.lua" (
      baseConfig + "\n" + extraConfig
    );

    wrappersModule = {...}: {
      args = [
        "--config"
        "${configFile}"
      ];
    };

    rawPkg =
      (inputs.wrappers.wrapperModules.hyprland.apply {
        inherit pkgs;
        imports = [wrappersModule];
      }).wrapper;
  in
    pkgs.symlinkJoin {
      name = "hyprland-custom";
      paths = [rawPkg];

      meta =
        rawPkg.meta
        // {
          outputsToInstall =
            builtins.filter
            (o: o != "man")
            (rawPkg.meta.outputsToInstall or ["out"]);
        };

      passthru =
        rawPkg.passthru
        // {
          inherit (rawPkg) override overrideAttrs;
          version = rawPkg.version;
        };
    };
in {
  flake.mkHyprlandPkg = mkHyprlandPkg;

  flake.packages.x86_64-linux.hyprland = mkHyprlandPkg {
    pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
  };

  flake.nixosModules.shells-hyprland = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.shells.hyprland;

    # Registered first so the outputs exist before the desktop's own start hooks.
    headlessLua = lib.optionalString cfg.headless ''
      hl.on("hyprland.start", function()
        ${lib.concatMapStringsSep "\n  " (o: ''hl.exec_cmd("hyprctl output create headless ${o}")'') cfg.headlessOutputs}
      end)
    '';

    hyprlandPkg = self.mkHyprlandPkg {
      inherit pkgs;
      extraConfig = headlessLua + "\n" + cfg.extraConfig;
    };
  in {
    options.shells.hyprland = {
      enable = lib.mkEnableOption "Hyprland desktop";

      extraConfig = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Additional host-specific Hyprland Lua configuration.";
      };

      extraWayleConfig = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Additional host-specific Wayle TOML configuration.";
      };

      headless = lib.mkOption {
        type = lib.types.bool;
        default = config.boot.isContainer;
        description = ''
          Run without a display manager or seat: Hyprland uses the headless
          backend and starts as a systemd user service.
        '';
      };

      headlessOutputs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Headless outputs to create at startup (only used when headless).";
      };
    };

    config = lib.mkIf cfg.enable (lib.mkMerge [
      {
        environment.systemPackages = [hyprlandPkg pkgs.rofi];
        programs.xwayland.enable = true;

        shells.wayle = {
          enable = true;
          extraConfig = cfg.extraWayleConfig;
        };
      }

      (lib.mkIf (!cfg.headless) {
        displayManager = {
          enable = true;
          backend = "greetd";
          autoLogin = true;
          sessionCommand = "${hyprlandPkg}/bin/start-hyprland";
        };
      })

      (lib.mkIf cfg.headless {
        # Gives the user a /run/user/<uid> and a user manager without a login.
        users.users.${config.username}.linger = true;

        systemd.user.services.hyprland-session = {
          description = "Hyprland session (headless)";
          wantedBy = ["default.target"];
          path = [config.system.path];
          environment = {
            XDG_SESSION_TYPE = "wayland";
            XDG_DATA_DIRS = "/run/current-system/sw/share";
            AQ_BACKENDS = "headless,libinput";
            LIBSEAT_BACKEND = "noop";
          };
          serviceConfig = {
            ExecStart = "${hyprlandPkg}/bin/hyprland";
            Restart = "always";
          };
        };
      })
    ]);
  };
}
