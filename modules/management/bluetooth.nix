{
  lib,
  config,
  pkgs,
  ...
}:
{
  options = {
    enable.bluetooth = lib.mkEnableOption "enable bluetooth";
  };
  config = lib.mkIf config.enable.bluetooth {
    services.blueman.enable = true;
    environment.systemPackages = [ pkgs.bluez ];
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings = {
        General = {
          Experimental = true;
          FastConnectable = true;
        };
        Policy = {
          AutoEnable = true;
        };
      };
    };
  };
}
