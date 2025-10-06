{
  config,
  lib,
  ...
}:
{
  options = {
    enable.docker = lib.mkEnableOption "enables dev tools";
  };
  config = lib.mkIf config.enable.docker {
    virtualisation.docker = {
      enable = true;
    };

    users.users.pete = {
      extraGroups = [ "docker" ];
    };

    systemd.services.docker.enable = true;

  };
}
