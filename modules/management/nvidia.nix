{
  config,
  lib,
  ...
}:
{
  options = {
    enable.nvidia = lib.mkEnableOption "enables nvida GPUS";
  };
  config = lib.mkIf config.enable.nvidia {

    hardware.opengl = {
      enable = true;
      enable32Bit = true;
      driSupport32Bit = true;
    };

    services.xserver.videoDrivers = [ "nvidia" ];

    hardware.nvidia = {
      modesetting.enable = true;
      powerManagement.enable = false;

      powerManagement.finegrained = false;
      open = true;

      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.stable;
    };

  };
}
