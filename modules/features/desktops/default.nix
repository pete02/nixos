{self, ...}: {
  flake.nixosModules.desktops = {
    lib,
    pkgs,
    config,
    ...
  }: let
    inherit (lib) mkOption mkIf mkMerge mkDefault types optionals;

  # A named desktop definition: the shell it uses, its package set, the Hyprland
  # Lua and Wayle TOML that complete it, and whether the cleaner service runs.
  # `extraConfig` and `hyprlandPkg` are derived from the def's own `hyprland.extraConfig`
  # and are what the streaming containers consume (see streaming-desktops:
  # `config.desktops.<name>.{packages,extraConfig,hyprlandPkg}`).
  mkDesktopOptions = name: default: {
    shell = mkOption {
      type = types.enum ["hyprland" "plasma-bigscreen" "pegasus-cage"];
      default = default.shell or "hyprland";
      description = ''
        Which window-manager shell this desktop activates. The `desktops` module
        enables the matching `shells.*` option when this desktop is selected.
      '';
    };

    packages = mkOption {
      type = types.listOf types.package;
      default = default.packages or [];
      description = ''
        Packages this desktop adds on top of the shell plumbing in
        `shells-services` (which already ships the base desktop tools).
        Also pulled into streaming containers that reference this def.
      '';
    };

    hyprland = {
      extraConfig = mkOption {
        type = types.lines;
        default = default.hyprland.extraConfig or "";
        description = "Host-specific Hyprland Lua (monitors, workspace rules, binds).";
      };
    };

    wayle = {
      extraConfig = mkOption {
        type = types.lines;
        default = default.wayle.extraConfig or "";
        description = "Host-specific Wayle TOML appended after base.toml.";
      };
    };

    services = {
      cleaner = mkOption {
        type = types.bool;
        default = default.services.cleaner or false;
        description = "Enable the Downloads/Trash cleaner service for this desktop.";
      };
    };

    # ---- derived: consumed by streaming-desktops containers ----
    extraConfig = mkOption {
      type = types.lines;
      default = config.desktops.${name}.hyprland.extraConfig;
      defaultText = lib.literalExpression "config.desktops.<name>.hyprland.extraConfig";
      description = "Effective Hyprland extraConfig for this def (its hyprland.extraConfig).";
    };

    hyprlandPkg = mkOption {
      type = types.package;
      default = self.mkHyprlandPkg {
        inherit pkgs;
        extraConfig = config.desktops.${name}.hyprland.extraConfig;
      };
      defaultText = lib.literalExpression "self.mkHyprlandPkg { inherit pkgs; extraConfig = config.desktops.<name>.hyprland.extraConfig; }";
      description = "Compositor package for this def (base.lua + its extraConfig).";
    };
  };

  # The three named desktops (user override: named after the hosts).
  desktopDefs = {
    raysha = {
      shell = "hyprland";
      services.cleaner = true;
    };
    talia = {
      shell = "hyprland";
      services.cleaner = true;
    };
    alanna = {
      shell = "pegasus-cage";
    };
  };
in {
  options.desktops = {
    desktop = mkOption {
      type = types.enum ([""] ++ builtins.attrNames desktopDefs);
      default = "";
      description = ''
        Name of the desktop def to activate on this host. `""` selects none
        (the host wires its shells directly). Setting it enables that desktop's
        shell, packages, config and cleaner.
      '';
    };
  }
  // lib.mapAttrs (name: def: mkDesktopOptions name def) desktopDefs;

  config = let
    sel = config.desktops.desktop;
    active = sel != "" && config.desktops ? ${sel};
    d = config.desktops.${sel};
  in
    mkIf active {
      shells.enable = mkIf (d.shell == "hyprland") true;
      shells.hyprland.enable = mkIf (d.shell == "hyprland") true;
      shells.hyprland.extraConfig = mkIf (d.shell == "hyprland") d.hyprland.extraConfig;
      shells.hyprland.extraWayleConfig = mkIf (d.shell == "hyprland") d.wayle.extraConfig;
      shells.plasma-bigscreen.enable = mkIf (d.shell == "plasma-bigscreen") true;
      shells.pegasus-cage.enable = mkIf (d.shell == "pegasus-cage") true;
      shells.services.cleaner = d.services.cleaner;
      environment.systemPackages = d.packages;
    };
  };
}
