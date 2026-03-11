{
  config,
  lib,
  pkgs,
  ...
}:
{
  options = {
    enable.docker = lib.mkEnableOption "enables dev tools";
    enable.docker-nvidia = lib.mkEnableOption "enables docker nvidia";
  };
  config = lib.mkIf config.enable.docker {
    virtualisation.docker = {
      enable = true;
      enableOnBoot = false;
      daemon.settings = {
        features = {
          cdi = true;
        };
      };
    };

    users.users.pete = {
      extraGroups = [ "docker" ];
    };

  };
}
