{self,inputs,pkgs, ...}:{
  flake.nixosModules.management={config, lib,pkgs, ...}:let
      rebuild-script = pkgs.writeShellScriptBin "rebuild" (
        builtins.readFile "${self}/scripts/rebuild.sh"
      );
    in
    {
    options= {
      username= lib.mkOption {
        type = lib.types.str;
        description = "The username of the main user";
      };

      management= {
        powersave = lib.mkEnableOption "Enable power saving";
      };
    };
    config= lib.mkMerge [
      ({
        users.users.${config.username} = {
          isNormalUser = true;
          extraGroups = [
            "wheel"
            "seat"
            "dialout"
            "uucp"
          ];
        };
        time.timeZone = "Europe/Helsinki";
        i18n.defaultLocale = "fi_FI.UTF-8";

          nix.settings.experimental-features = [
            "nix-command"
            "flakes"
          ];
          nixpkgs.config.allowUnfree = true;
          environment.systemPackages = [
            pkgs.nixfmt-tree
            pkgs.libnotify
            pkgs.nvd
            pkgs.vulnix
            pkgs.lm_sensors
            pkgs.fastfetch
            rebuild-script
          ];

          nix.gc = {
            automatic = true;
            dates = "daily";
            options = "--delete-older-than 7d";
          };
          nix.settings.auto-optimise-store = true;

      })
      (lib.mkIf (config.management.powersave != null) {
          environment.systemPackages = with pkgs; [
            tlp
          ];

          services.thermald.enable = true;

          services.tlp = {
            settings = {
              CPU_BOOST_ON_AC = 1;
              CPU_BOOST_ON_BAT = 0;
              CPU_SCALING_GOVERNOR_ON_AC = "performance";
              CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
            };
          };
      })
    ];
  };
}