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
    programs.steam = {
      enable = true;
      extraCompatPackages = with pkgs; [
        vkd3d-proton
        vkd3d
        dxvk_2
        proton-ge-bin
        freetype
        openjdk21_headless
        wineWowPackages.waylandFull
        gamescope-wsi
        vulkan-loader
      ];
    };
    programs.gamescope = {
      enable = true;
      package = gamescope-pkg;
    };
    environment.systemPackages = with pkgs; [
      mangohud
      protonup
    ];
    programs.gamemode.enable = true;
  };
}
