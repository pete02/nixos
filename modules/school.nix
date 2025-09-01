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
    environment.systemPackages = with pkgs; [
      obsidian
      wineWowPackages.waylandFull
    ];

    nixpkgs.overlays = [
      (self: super: {
        obsidian = super.obsidian.override {
          commandLineArgs = "--ozone-platform=wayland";
        };
      })
    ]
    ;
  };
}
