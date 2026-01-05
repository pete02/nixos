{
  config,
  lib,
  ...
}:
{
  options = {
    enable.nvidia-host = lib.mkEnableOption "enables nvida GPUS";
  };
  config = lib.mkIf config.enable.nvidia {
    assertions = [
      {
        assertion = (!config.enable.nvidia.passthrough && config.enable.amdgpu == [ ]);
        message = "VFIO passthrough enabled but no PCI IDs specified.";
      }
    ];

    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };

    services.xserver.videoDrivers = [ "nvidia" ];
    hardware.nvidia-container-toolkit.enable = true;
    hardware.nvidia = {
      modesetting.enable = true;
      powerManagement.enable = false;

      powerManagement.finegrained = false;
      open = false;

      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.stable;
    };

    boot.kernelModules = [
      "nvidia"
      "nvidia_modeset"
      "nvidia_uvm"
      "nvidia_drm"
    ];

    boot.blacklistedKernelModules = [
      "amdgpu"
      "kvm"
      "kvm_amd"
    ];

    boot.kernelParams = lib.optionals (!config.settings.virtualisation.enable) [
      "drm.edid_firmware=DP-2:/boot/edid/monitor.bin"
      "nvidia-drm.modeset=1"
      "nvidia_drm.modeset=1"
      "nvidia.NVreg_UseVBiosModeset=1"
      "nvidia.NVreg_RegistryDwords=EnablePrimaryDisplay=1"
      "video=3440x1440@175"
    ];
  };
}
