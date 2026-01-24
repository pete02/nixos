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
<<<<<<< HEAD
      pkgs.appimage-run
=======
      appimage-run
>>>>>>> 64d4446 (Rebuild on raysha: 2026-01-24 09:54:43)
    ];
  };
}
