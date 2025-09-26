{
  pkgs,
  config,
  lib,
  ...
}:
{
  options = {
    enable.razer = lib.mkEnableOption "enable razer";
  };
  config = {
    environment.systemPackages = with pkgs; [
      openrazer-daemon
      polychromatic
    ];

    users.users.${config.username} = {
      extraGroups = [ "openrazer" ];
    };
  };
}
