{
  config,
  lib,
  pkgs,
  ...
}:
{
  options = {
    enable.school = lib.mkEnableOption "enables school tools";
  };
  config = lib.mkIf config.enable.school {

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
