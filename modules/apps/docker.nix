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

      rootless = {
        enable = true;
        setSocketVariable = true;
        # Optionally customize rootless Docker daemon settings
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

    systemd.services.docker.enable = false;
    systemd.services.docker.socket.enable = true;
  };
}
