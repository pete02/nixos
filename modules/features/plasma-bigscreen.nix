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
      kdePackages.plasma-workspace
      kdePackages.kdeconnect-kde
    ];
    services = {
      desktopManager.plasma6.enable = true;

      displayManager = {
        sessionPackages = [
          pkgs.kdePackages.plasma-bigscreen
        ];

        defaultSession = "plasma-bigscreen-wayland";

        autoLogin = {
          enable = true;
          user = config.username;
        };

        sddm = {
          enable = true;
          wayland.enable = true;
        };
      };
    };
  };
}
