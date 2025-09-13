{ lib, config, ... }:
{
  options = {
    enable.wireless = lib.mkEnableOption "enables wireless";
  };
  config = lib.mkIf config.enable.wireless {
    networking.wireless.enable = false;
    networking.networkmanager.enable = true;
    systemd.services.NetworkManager-wait-online.enable = false;
  };
}
