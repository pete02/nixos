{...}: {
  flake.nixosModules.gaming-compatibility = {
    lib,
    pkgs,
    config,
    ...
  }: {
    options.gaming.compatibility =
      lib.mkEnableOption "Gaming compatibility tools";

    config = lib.mkIf config.gaming.compatibility {
      environment.systemPackages = with pkgs; [
        steam-run
        wineWow64Packages.waylandFull
        protonup-ng
        lutris
        umu-launcher
      ];
    };
  };
}
