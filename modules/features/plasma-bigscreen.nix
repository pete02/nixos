{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.plasmaBigscreen = {
    config,
    lib,
    pkgs,
    ...
  }: {
    services = {
      desktopManager.plasma6.enable = true;

      displayManager.sddm = {
        enable = true;
        wayland.enable = true;

        autoLogin = {
          enable = true;
          user = "${config.username}";
        };
      };
    };
  };
}
