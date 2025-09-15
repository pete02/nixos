{ lib, config, ... }:
{
  options = {
    enable.kde = lib.mkEnableOption "use KDE";
  };
  config = lib.mkIf config.enable.kde {
    services.xserver.enable = true; # optional
    services.displayManager.sddm.enable = true;
    services.displayManager.sddm.wayland.enable = true;
    services.desktopManager.plasma6.enable = true;
  };
}
