
{
  self,
  inputs,
  lib,
  ...
}: let
  baseConfig = builtins.readFile ./base.conf;

  wrappersModule = {confFile, ...}: {
    args = [
      "--config"
      "${confFile}"
    ];
  };

  mkHyprlandPkg = {
    pkgs,
    extraConfig ? "",
  }: let
    confFile = pkgs.writeText "hyprland.conf" (
      baseConfig + "\n" + extraConfig
    );

    rawPkg =
      (inputs.wrappers.wrapperModules.hyprland.apply {
        inherit pkgs;
        imports = [wrappersModule];
        _module.args = {inherit confFile;};
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
        description = "Additional host-specific Hyprland configuration.";
      };
      extraWayleConfig = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Additional host-specific Hyprland configuration.";
      };
    };

    config = lib.mkIf cfg.enable {
      environment.systemPackages = [hyprlandPkg];

      displayManager = {
        enable = true;
        backend = "greetd";
        autoLogin = true;

        sessionCommand =
          "${hyprlandPkg}/bin/start-hyprland --path ${hyprlandPkg}/bin/hyprland";
      };

      desktop.wayle = {
        enable = true;

        extraConfig = cfg.extraWayleConfig;
      };
    };
  };
}
