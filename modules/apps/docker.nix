{
  config,
  lib,
  ...
}:
{
  options = {
    docker.enable = lib.mkEnableOption "enables dev tools";
  };
  config = lib.mkIf config.podman.enable {
    virtualisation.docker.enable = true;
    virtualisation.docker.storageDriver = "btrfs";

    users.users.pete = {
      extraGroups = [ "docker" ];
    };
  };
}
