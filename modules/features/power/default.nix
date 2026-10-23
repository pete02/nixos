{
  ...
}: {
  flake.nixosModules.power = {
    lib,
    config,
    pkgs,
    ...
  }: {
    options.power.powersave = lib.mkEnableOption "Enable power saving";
    config = lib.mkIf (config.power.powersave) {
      environment.systemPackages = with pkgs; [
        tlp
      ];

      services.thermald.enable = true;

      services.tlp = {
        settings = {
          CPU_BOOST_ON_AC = 1;
          CPU_BOOST_ON_BAT = 0;
          CPU_SCALING_GOVERNOR_ON_AC = "performance";
          CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
        };
      };
    };
  };
}
