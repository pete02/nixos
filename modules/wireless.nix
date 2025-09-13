{ ... }:
{
  options = {
    wireless.enable = lib.mkEnableOption "enables wireless";
  };
  config = lib.mkIf config.wireless.enable {
    networking.wireless.enable = false;
    networking.networkmanager.enable = true;
    systemd.services.NetworkManager-wait-online.enable = false;
  };
}
