{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.gaming = {
    lib,
    pkgs,
    config,
    ...
  }: let
    cfg = config.gaming.sunshine;

    stable = import inputs.nixpkgs-stable {
      system = pkgs.stdenv.hostPlatform.system;
      config.allowUnfreePredicate = pkg:
        builtins.elem (lib.getName pkg) [
          "rpcs3"
        ];
    };
  in {
    options.gaming.sunshine.enable = lib.mkEnableOption "Sunshine game streaming";

    config = {
      programs.steam = {
        enable = true;
        gamescopeSession.enable = true;
      };

      programs.gamescope = {
        enable = true;
        capSysNice = false;
      };

      environment.systemPackages = with pkgs;
        [
          mangohud
          wineWow64Packages.waylandFull
          mesa-demos
          protonup-ng
          lutris
          umu-launcher
          dejavu_fonts
          self.packages.${pkgs.stdenv.hostPlatform.system}.rpcs3
        ]
        ++ lib.optionals cfg.enable [
          self.packages.${pkgs.stdenv.hostPlatform.system}.sunshine-launcher
        ];

      nixpkgs.config.packageOverrides = pkgs: {
        steam = pkgs.steam.override {
          extraPkgs = pkgs:
            with pkgs; [
              libXi
              libXinerama
              libXScrnSaver
              libpng
              libpulseaudio
              libvorbis
              stdenv.cc.cc.lib
              libkrb5
              keyutils
              winetricks
            ];
        };
      };

      programs.gamemode.enable = true;
      services.seatd.enable = false;

      hardware.display.edid.modelines = lib.mkIf cfg.enable {
        sunshine-4k60 = ''
          533.00  3840 3888 3920 4000  2160 2163 2168 2222  +hsync -vsync
        '';
      };

      boot.kernelParams = lib.mkIf cfg.enable [
        "drm.edid_firmware=HDMI-A-1:edid/sunshine-4k60.bin"
        "video=HDMI-A-1:e"
      ];

      services.sunshine = lib.mkIf cfg.enable {
        enable = true;
        capSysAdmin = true;
        openFirewall = true;

        settings = {
          capture = "wlr";
        };
      };

      systemd.user.services.sunshine = lib.mkIf cfg.enable {
        wantedBy = ["default.target"];
      };

      hardware.uinput.enable = lib.mkIf cfg.enable true;

      users.users.${config.username}.extraGroups = lib.mkIf cfg.enable [
        "uinput"
      ];
    };
  };
}
