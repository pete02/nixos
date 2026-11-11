{...}: {
  flake.nixosModules.shells-selection = {config, ...}: {
    assertions = [
      {
        assertion =
          builtins.length (
            builtins.filter (enabled: enabled) [
              config.shells.hyprland.enable
              config.shells.plasma-bigscreen.enable
            ]
          )
          <= 1;

        message = ''
          Only one desktop environment can be enabled at a time.
          Choose either shells.hyprland.enable or
          shells.plasma-bigscreen.enable.
        '';
      }
    ];
  };
}
