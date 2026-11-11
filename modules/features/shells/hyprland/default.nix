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
    hyprlandPkg = self.mkHyprlandPkg {
      inherit pkgs;
      extraConfig = config.shells.hyprland.extraConfig;
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
    };

    config = lib.mkIf config.shells.hyprland.enable {
      environment.systemPackages = [hyprlandPkg];
      programs.xwayland.enable = true;
      displayManager = {
        enable = true;
        backend = "greetd";
        autoLogin = true;

        sessionCommand = "${hyprlandPkg}/bin/start-hyprland --path ${hyprlandPkg}/bin/hyprland";
      };

      shells.wayle = {
        enable = true;
        extraConfig = config.shells.hyprland.extraWayleConfig;
      };
    };
  };
}
