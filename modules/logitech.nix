{
  pkgs,
  lib,
  config,
  ...
}:
{
  options = {
    enable.logitech = lib.mkEnableOption "Enable Solaar (logitech hub alternative)";
  };
  config = lib.mkIf config.enable.logitech {
    config.enable.virtualisation = true;
    environment.systemPackages = [ pkgs.logiops ];

    hardware.logitech.wireless.enable = true;
  };
}
