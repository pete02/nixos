{
  config,
  lib,
  pkgs,
  ...
}:
{
  options = {
    school.enable = lib.mkEnableOption "enables school tools";
  };
  config = lib.mkIf config.school.enable {

    nixpkgs.overlays = [
      (self: super: {
        obsidian = super.obsidian.override {
          commandLineArgs = "--ozone-platform=wayland";
        };
      })
    ];

    environment.systemPackages = with pkgs; [
      obsidian
      wineWow64Packages.waylandFull
    ];
  };
}
