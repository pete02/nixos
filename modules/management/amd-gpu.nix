{ config, lib, ... }:
{
  config = lib.mkIf (!config.enable.nvidia-host && !config.enable.nvidia-host-legacy) {
    services.xserver.videoDrivers = [ "amdgpu" ];

    hardware = {
      graphics = {
        enable = true;
        enable32Bit = true;
      };
      amdgpu.opencl.enable = true;
      amdgpu.initrd.enable = true;
    };

    boot.kernelModules = [ "amdgpu" ];
    boot.blacklistedKernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];
  };
}
