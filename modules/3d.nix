{
  lib,
  config,
  pkgs,
  ...
}:
{
  options = {
    enable.modeling = lib.mkEnableOption "enables 3d modeling tools";
  };
  config = lib.mkIf config.enable.books {
    environment.systemPackages = [
      pkgs.freecad
      appimage-run
    ];
  };
}
