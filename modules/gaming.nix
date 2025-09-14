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
    hardware.graphics = {
      extraPackages = [ pkgs.gamescope-wsi ];
      extraPackages32 = [ pkgs.pkgsi686Linux.gamescope-wsi ];
      enable = true;
      enable32Bit = true;
    };

    programs.steam = {
      enable = true;
      gamescopeSession.enable = true;
    };

    programs.gamescope = {
      enable = true;
      capSysNice = true;
    };
    environment.systemPackages = with pkgs; [
      mangohud
      protonup
    ];

    nixpkgs.overlays = [
      (_: prev: {
        gamescope = prev.gamescope.overrideAttrs (_: rec {
          version = "3.16.17";
          src = prev.fetchFromGitHub {
            owner = "ValveSoftware";
            repo = "gamescope";
            rev = "refs/tags/${version}";
            fetchSubmodules = true;
            hash = "sha256-q3HEbFqUeNczKYUlou+quxawCTjpM5JNLrML84tZVYE=";
          };
        });
      })
    ];
    programs.gamemode.enable = true;
  };
}
