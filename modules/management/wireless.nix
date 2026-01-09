{ lib, config, ... }:
{
  options = {
    enable.wireless = lib.mkEnableOption "enables wireless";
  };
  config = lib.mkIf config.enable.wireless {
    networking.wireless.enable = true;
    networking.networkmanager.enable = lib.mkForce true;
    systemd.services.NetworkManager-wait-online.enable = false;
  };
}
