{
  config,
  lib,
  pkgs,
  ...
}:
{
  options = {
    enable.nvidia-host = lib.mkEnableOption "enables nvidia GPU (current driver)";
  };

  config = lib.mkIf config.enable.nvidia-host {
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
        package = config.boot.kernelPackages.nvidiaPackages.stable;
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
