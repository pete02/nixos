{ pkgs, config, ... }:
{
  environment.systemPackages = with pkgs; [
    openrazer-daemon
    polychormatic
  ];

  users.users.${config.username} = {
    extraGroups = [ "openrazer" ];
  };

}
