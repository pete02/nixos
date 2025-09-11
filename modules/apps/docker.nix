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
      enable = false;

      rootless = {
        enable = true;
        setSocketVariable = true;
        daemon.settings = {
          dns = [
            "1.1.1.1"
            "8.8.8.8"
          ];
          registry-mirrors = [ "https://mirror.gcr.io" ];
        };
      };
    };

    users.users.pete = {
      extraGroups = [ "docker" ];
    };
  };
}
