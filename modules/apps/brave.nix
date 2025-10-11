{
  lib,
  pkgs,
  config,
  ...
}:
{
  options.enable.brave = lib.mkEnableOption "Enable Brave browser";

  config = lib.mkIf config.enable.brave {
    nixpkgs.overlays = [
      (self: super: {
        brave = super.brave.override {
          commandLineArgs = "--ozone-platform=x11";
        };
      })
    ];

    environment.systemPackages = [ pkgs.brave ];
  };
}
