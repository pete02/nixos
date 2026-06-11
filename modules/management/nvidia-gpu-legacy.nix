{
  config,
  lib,
  pkgs,
  ...
}:
{
  options = {
    enable.nvidia-host-legacy = lib.mkEnableOption "enables nvidia GPU (legacy driver for GTX 900/1000 series)";
  };

  config = lib.mkIf config.enable.nvidia-host-legacy {
    services.xserver.videoDrivers = [ "nvidia" ];

    environment.systemPackages = [ pkgs.nvidia-container-toolkit ];

    hardware = {
      graphics = {
        enable = true;
        enable32Bit = true;
      };
      nvidia-container-toolkit.enable = true;
      nvidia = {
        modesetting.enable = true;
        powerManagement.enable = false;
        powerManagement.finegrained = false;
        open = false;
        nvidiaSettings = true;
        package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
      };
    };

    boot.kernelModules = [
      "nvidia"
      "nvidia_modeset"
      "nvidia_uvm"
      "nvidia_drm"
    ];
    boot.blacklistedKernelModules = [ "amdgpu" ];
    boot.kernelParams = [ "nvidia-drm.modeset=1" ];
    boot.initrd.kernelModules = [
      "nvidia"
      "nvidia_modeset"
      "nvidia_uvm"
      "nvidia_drm"
    ];
  };
}
