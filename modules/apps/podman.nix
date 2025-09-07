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

    users.users.pete = {
      extraGroups = [ "podman" ];
    };

    environment.systemPackages = with pkgs; [
      podman
      podman-compose

    ];

  };
}
