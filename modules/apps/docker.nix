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
      enableOnBoot = true;
      daemon.settings = {
        features.cdi = true;
        # Optionally make nvidia the default:
        default-runtime = "nvidia";
      };
    };

    users.users.pete = {
      extraGroups = [ "docker" ];
    };

  };
}
