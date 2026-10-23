{
  ...
}: {
  flake.nixosModules.connectivity-bluetooth = {
    config,
    lib,
    ...
  }: {
    options = {
      connectivity.bluetooth = lib.mkEnableOption "bluetooth";
    };

    config = lib.mkIf config.connectivity.bluetooth {
      hardware.bluetooth = {
        enable = true;
        powerOnBoot = true;
        settings = {
          General = {
            Experimental = true;
            FastConnectable = true;
          };
          Policy.AutoEnable = true;
        };
      };
      services.blueman.enable = true;
    };
  };
}
