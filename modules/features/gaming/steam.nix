{...}: {
  flake.nixosModules.gaming-steam = {
    lib,
    config,
    ...
  }: {
    options.gaming.steam = lib.mkEnableOption "Enables Steam";
    config = lib.mkIf config.gaming.steam {
      programs.steam = {
        enable = true;
        gamescopeSession.enable = true;
      };

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
    };
  };
}
