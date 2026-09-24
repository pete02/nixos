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
    services.displayManager = {
      sessionPackages = [
        pkgs.kdePackages.plasma-bigscreen
      ];

      defaultSession = "plasma-bigscreen-wayland";

      sddm = {
        enable = true;
        wayland.enable = true;

        autoLogin = {
          enable = true;
          user = config.username;
        };
      };
    };
  };
}
