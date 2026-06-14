{ self, inputs, ... }: {
  flake.nixosModules.management =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options = {
        username = lib.mkOption {
          type = lib.types.str;
          description = "The username of the main user";
        };

        management = {
          sshClient = lib.mkEnableOption "enables ssh client";
          powersave = lib.mkEnableOption "Enable power saving";
          ld = lib.mkEnableOption "enables nix-ld";
        };
      };
      config = lib.mkMerge [
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
          environment.systemPackages = with pkgs; [
            nixfmt-tree
            libnotify
            nvd
            vulnix
            lm_sensors
            fastfetch
            writeShellScriptBin
            "rebuild"
            (builtins.readFile "${self}/scripts/rebuild.sh")
          ];

          nix.gc = {
            automatic = true;
            dates = "daily";
            options = "--delete-older-than 7d";
          };
          nix.settings.auto-optimise-store = true;

        })
        (lib.mkIf (config.management.powersave) {
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
        (lib.mkIf (config.management.ld) {
          programs.nix-ld = {
            enable = true;
            libraries = with pkgs; [
              stdenv.cc.cc
              zlib
              glibc
              libgcc
              libffi
              openssl
            ];
          };
        })
        (lib.mkIf (config.management.sshClient) {
          sops.secrets."ssh/${config.username}/servu" = { 
            owner= config.username;
          };
          
          sops.secrets."ssh/${config.username}/github" = { 
            owner= config.username;
          };

          environment.etc."ssh/ssh_config".text = ''
            Host github.com
              hostname github.com
              identityFile /run/secrets/ssh/${config.username}/github
              user git

            Host servu
              hostname 192.168.88.241
              identityFile /run/secrets/ssh/${config.username}/servu
              port 22
              user pete
          '';
        })
      ];
    };
}
