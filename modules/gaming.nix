{
  config,
  lib,
  pkgs,
  ...
}:
let
  conf = config;
in
{
  options = {
    enable.gaming = lib.mkEnableOption "enables gaming tools";
  };
  config = lib.mkIf config.enable.gaming {
    programs.steam.enable = true;
    programs.steam.gamescopeSession.enable = true;
    environment.systemPackages = with pkgs; [
      mangohud
      protonup
    ];
    programs.gamemode.enable = true;

    users.users.${conf.username}.extraGroups = [
      "video"
    ];
  };
}
