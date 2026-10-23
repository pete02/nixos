{lib, ...}: {
  flake.nixosModules.desktop-wayle = {
    config,
    pkgs,
    ...
  }: let
    cfg = config.desktop.wayle;

    extraToml =
      pkgs.writeText
      "wayle-extra.toml"
      cfg.extraConfig;

    wayleConfig = pkgs.runCommand "wayle-config" {} ''
            mkdir -p "$out"

            cp ${./base.toml} "$out/base.toml"
            cp ${extraToml} "$out/extra.toml"

            cat > "$out/config.toml" <<'EOF'
      imports = [
        "base.toml",
        "extra.toml",
      ]
      EOF
    '';
  in {
    options.desktop.wayle = {
      enable = lib.mkEnableOption "Wayle desktop shell";

      configDir = lib.mkOption {
        type = lib.types.str;
        default = "/home/${config.username}/.config/wayle";
        description = "Directory in which Wayle reads its configuration.";
      };

      extraConfig = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = ''
          Additional TOML configuration imported after base.toml.
          Values in this file override matching base configuration values.
        '';
      };
    };

    config = lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = config.username != "";
          message = "The username used by desktop.wayle must not be empty.";
        }
        {
          assertion = lib.hasPrefix "/" cfg.configDir;
          message = "desktop.wayle.configDir must be an absolute path.";
        }
      ];
      environment.systemPackages = [pkgs.wayle];
      systemd.tmpfiles.rules = [
        "d ${cfg.configDir} 0755 ${config.username} users - -"
        "L+ ${cfg.configDir}/config.toml - - - - ${wayleConfig}/config.toml"
        "L+ ${cfg.configDir}/base.toml - - - - ${wayleConfig}/base.toml"
        "L+ ${cfg.configDir}/extra.toml - - - - ${wayleConfig}/extra.toml"
      ];
    };
  };
}
