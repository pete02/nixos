{
  config,
  lib,
  pkgs,
  ...
}:
let
  gamescope-pkg = pkgs.gamescope.overrideAttrs {
    version = "3.14.22";
    src = pkgs.fetchFromGitHub {
      owner = "ValveSoftware";
      repo = "gamescope";
      rev = "refs/tags/3.14.22";
      fetchSubmodules = true;
      hash = "sha256-/muitEE3LCU6Xnjbpczb/zy2JRvUbBPT5L13T/v3MvE=";
    };
  };
in
{
  options = {
    enable.gaming = lib.mkEnableOption "enables gaming tools";
  };
  config = lib.mkIf config.enable.gaming {
    programs.steam.enable = true;
    programs.gamescope.enable = true;
    environment.systemPackages = with pkgs; [
      mangohud
      protonup
    ];
    nixpkgs.overlays = [
      (_: prev: {
        gamescope = prev.gamescope.overrideAttrs (_: rec {
          version = "3.14.29";
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
