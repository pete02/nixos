{
  config,
  lib,
  pkgs,
  ...
}:
{
  options = {
    enable.gaming = lib.mkEnableOption "enables gaming tools";
  };
  config = lib.mkIf config.enable.gaming {

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
    ];

    nixpkgs.config.packageOverrides = pkgs: {
      steam = pkgs.steam.override {
        extraPkgs =
          pkgs: with pkgs; [
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
  };
}
