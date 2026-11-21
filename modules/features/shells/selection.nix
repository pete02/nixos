{...}: {
  flake.nixosModules.shells-selection = {config, ...}: {
    assertions = [
      {
        assertion =
          builtins.length (
            builtins.filter (enabled: enabled) [
              config.shells.hyprland.enable
              config.shells.plasma-bigscreen.enable
              config.shells.cage.enable
            ]
          )
          <= 1;

        message = ''
          Only one desktop environment can be enabled at a time.
          Choose one of shells.hyprland.enable,
          shells.plasma-bigscreen.enable or shells.cage.enable.
        '';
      }
    ];
  };
}
