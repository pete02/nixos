{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
{
  options = {
    enable.gaming = lib.mkEnableOption "enables gaming tools";
  };
  config = lib.mkIf config.enable.gaming {
    hardware.opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
    };

    programs.steam.enable = true;
    programs.steam.gamescopeSession.enable = true;
    environment.systemPackages = with pkgs; [
      mangohud
      protonup
    ];
    programs.gamemode.enable = true;
  };
}
