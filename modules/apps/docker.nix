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
      package = pkgs.docker_25;
    };

    users.users.pete = {
      extraGroups = [ "docker" ];
    };

    systemd.services.docker.enable = true;

  };
}
