{
  self,
  inputs,
  pkgs,
  ...
}: {
  flake.nixosModules.plasmaBigscreen = {
    config,
    lib,
    pkgs,
    ...
  }: {
    environment.systemPackages = with pkgs; [
      kdePackages.plasma-bigscreen
    ];

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
