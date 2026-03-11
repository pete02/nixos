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
        features.cdi = true;
        runtimes.nvidia = {
          path = "${pkgs.nvidia-container-toolkit}/bin/nvidia-container-runtime";
          runtimeArgs = [ ];
        };
        # Optionally make nvidia the default:
        default-runtime = "nvidia";
      };
    };

    users.users.pete = {
      extraGroups = [ "docker" ];
    };

  };
}
