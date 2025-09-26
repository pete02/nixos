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
    environment.systemPackages = [
      pkgs.piper
      pkgs.libratbag
    ];
    hardware.logitech.wireless.enable = true;
    services.ratbagd.enable = true;
  };
}
