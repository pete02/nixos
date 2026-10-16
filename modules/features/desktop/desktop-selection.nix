
{ lib, ... }: {
  flake.nixosModules.desktop-selection = {
    config,
    ...
  }: {
    assertions = [
      {
        assertion =
          builtins.length (
            builtins.filter (enabled: enabled) [
              config.desktop.hyprland.enable
              config.desktop.plasma-bigscreen.enable
            ]
          ) <= 1;

        message = ''
          Only one desktop environment can be enabled at a time.
          Choose either desktop.hyprland.enable or
          desktop.plasmaBigscreen.enable.
        '';
      }
    ];
  };
}
