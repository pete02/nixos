{
  config,
  lib,
  pkgs,
  ...
}:
{
  options = {
    school.enable = lib.mkEnableOption "enables dev tools";
  };
  config = lib.mkIf config.school.enable {
    environment.systemPackages = with pkgs; [
      obsidian
      (obsidian.overrideAttrs (e: rec {
        desktopItem = e.desktopItem.override (d: {
          exec = "${d.exec} --ozone-platform=wayland ";
        });
        installPhase = builtins.replaceStrings ["${e.desktopItem}"] ["${desktopItem}"] e.installPhase;
      }))
      wineWowPackages.waylandFull
    ];
  };
}
