{
  self,
  inputs,
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.desktop.hyprland;

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

  hyprlandPkg = mkHyprlandPkg {
    inherit pkgs;
    extraConfig = cfg.extraConfig;
  };
in {
  flake.mkHyprlandPkg = mkHyprlandPkg;

  flake.packages.x86_64-linux.hyprland = mkHyprlandPkg {
    pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
  };

  flake.nixosModules.desktop-hyprland = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.desktop.hyprland;

    hyprlandPkg = self.mkHyprlandPkg {
      inherit pkgs;
      extraConfig = cfg.extraConfig;
    };
  in {
    options.desktop.hyprland = {
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
    };

    config = lib.mkIf cfg.enable {
      environment.systemPackages = [hyprlandPkg];

      displayManager = {
        enable = true;
        backend = "greetd";
        autoLogin = true;

        sessionCommand = "${hyprlandPkg}/bin/start-hyprland --path ${hyprlandPkg}/bin/hyprland";
      };

      desktop.wayle = {
        enable = true;
        extraConfig = cfg.extraWayleConfig;
      };
    };
  };
}
