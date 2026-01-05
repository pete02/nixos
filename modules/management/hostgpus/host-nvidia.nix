{
  config,
  lib,
  ...
}:
{
  options = {
    enable.nvidia-host = lib.mkEnableOption "enables nvida GPUS";
  };
  config = {

    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };

    services.xserver.videoDrivers = [
      "nvidia"
    ]
    ++ lib.optionals (!config.enable.nvidia-host) [ "amdgpu" ];
    hardware.nvidia-container-toolkit.enable = true;
    hardware.nvidia = {
      modesetting.enable = true;
      powerManagement.enable = false;

      powerManagement.finegrained = false;
      open = false;

      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.stable;
    };

    boot.kernelModules = lib.optionals config.enable.nvidia-host [
      "nvidia"
      "nvidia_modeset"
      "nvidia_uvm"
      "nvidia_drm"
    ];

    boot.blacklistedKernelModules =
      lib.optionals config.enable.nvidia-host [
        "amdgpu"
      ]
      ++ lib.optionals (!config.enable.nvidia-host) [
        "nvidia"
        "nvidia_modeset"
        "nvidia_uvm"
        "nvidia_drm"
      ];

    boot.kernelParams = lib.optionals config.enable.nvidia-host [
      "drm.edid_firmware=DP-2:/boot/edid/monitor.bin"
      "nvidia-drm.modeset=1"
      "nvidia_drm.modeset=1"
      "nvidia.NVreg_UseVBiosModeset=1"
      "nvidia.NVreg_RegistryDwords=EnablePrimaryDisplay=1"
      "video=3440x1440@175"
    ];
  };
}
