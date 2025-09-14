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
    environment.systemPackages =
      with pkgs;
      [
        mangohud
        glxinfo
        protonup
        gamescope-wsi
      ]
      ++ [ stablePkgs.vulkan-tools ];
    programs.gamemode.enable = true;
  };
}
