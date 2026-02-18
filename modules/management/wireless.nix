{ lib, config, ... }:
{
  options = {
    enable.wireless = lib.mkEnableOption "enables wireless";
  };
  config = lib.mkIf config.enable.wireless {
    networking.wireless.enable = true;
    networking.wireless.extraConfig = "country=FI";
    networking.networkmanager.enable = lib.mkForce true;
    systemd.services.NetworkManager-wait-online.enable = false;
    users.users.${config.username}.extraGroups = [ "networkmanager" ];
  };
}
