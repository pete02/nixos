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

      environment.systemPackages = with pkgs; [
        mangohud
        wineWow64Packages.waylandFull
        mesa-demos
        protonup-ng
        lutris
        umu-launcher
        dejavu_fonts
        self.packages.${pkgs.stdenv.hostPlatform.system}.rpcs3
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

      services.sunshine = lib.mkIf cfg.enable {
        enable = true;
        autoStart = true;
        capSysAdmin = true;
        openFirewall = true;
      };

      hardware.uinput.enable = lib.mkIf cfg.enable true;

      users.users.${config.username}.extraGroups = lib.mkIf cfg.enable [
        "uinput"
      ];
    };
  };
}
