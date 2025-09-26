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
  config = {
    environment.systemPackages = [ pkgs.solaar ];
    hardware.logitech.wireless.enable = true;
  };
}
