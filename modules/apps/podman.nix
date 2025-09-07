{
  config,
  lib,
  pkgs,
  ...
}:
{
  options = {
    podman.enable = lib.mkEnableOption "enables dev tools";
  };
  config = lib.mkIf config.podman.enable {
    virtualisation.containers.enable = true;
    virtualisation = {
      podman = {
        enable = true;
        dockerCompat = true;
        defaultNetwork.settings.dns_enabled = true;
      };
    };

    virtualisation.containers.storage.settings = {
      storage = {
        driver = "btrfs";
        graphroot = "/var/lib/containers/storage";
        runroot = "/run/containers/storage";
      };
    };

    users.users.pete = {
      extraGroups = [ "podman" ];
    };

  };
}
