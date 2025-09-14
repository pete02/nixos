{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  stablePkgs = import inputs.nixpkgsStable { system = "x86_64-linux"; };
in
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
    environment.systemPackages =
      with pkgs;
      [
        mangohud
        glxinfo
        protonup
      ]
      ++ [
        stablePkgs.vulkan-tools
        stablePkgs.gamescope
        stablePkgs.gamescope-wsi
      ];
    programs.gamemode.enable = true;
  };
}
