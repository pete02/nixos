{ pkgs, config, ... }:
{
  environment.systemPackages = with pkgs; [
    openrazer-daemon
    polychromatic
  ];

  users.users.${config.username} = {
    extraGroups = [ "openrazer" ];
  };

}
