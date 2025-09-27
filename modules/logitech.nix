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
    enable.virtualisation = true;
    environment.systemPackages = with pkgs; [
      logiops
      piper
      libratbag
    ];

    hardware.logitech.wireless.enable = true;
  };
}
