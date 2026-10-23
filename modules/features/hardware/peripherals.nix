{...}: {
  flake.nixosModules.hardware-peripherals = {
    lib,
    pkgs,
    config,
    ...
  }: {
    options = {
      # Peripheral Options
      peripherals.logitech = lib.mkEnableOption "Logitech device support (logiops, piper, ratbagd)";
      peripherals.razer = lib.mkEnableOption "Razer device support (RGB lighting control)";
    };

    config = lib.mkMerge [
      # Logitech Device Support
      (lib.mkIf config.peripherals.logitech {
        environment.systemPackages = with pkgs; [
          logiops
          piper
          libratbag
        ];

        hardware.logitech.wireless.enable = true;

        services.ratbagd.enable = true;
      })

      # Razer Device Support (RGB lighting)
      (lib.mkIf config.peripherals.razer {
        environment.systemPackages = with pkgs; [
          openrazer-daemon
          polychromatic
        ];

        users.users.${config.username} = {
          extraGroups = ["openrazer"];
        };
      })
    ];
  };
}
