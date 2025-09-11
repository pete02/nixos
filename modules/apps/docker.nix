{
  config,
  lib,
  ...
}:
{
  options = {
    docker.enable = lib.mkEnableOption "enables dev tools";
  };
  config = lib.mkIf config.docker.enable {
    virtualisation.docker = {
      enable = true;
    };

    users.users.pete = {
      extraGroups = [ "docker" ];
    };
  };
}
