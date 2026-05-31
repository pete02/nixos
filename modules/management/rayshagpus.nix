{
  config,
  lib,
  pkgs,
  nixpkgs,
  ...
}:
{
  options = {
    enable.nvidia-host = lib.mkEnableOption "enables nvida GPUS";
  };
  config = {

    services.xserver.videoDrivers =
      lib.optionals config.enable.nvidia-host [
        "nvidia"
      ]
      ++ lib.optionals (!config.enable.nvidia-host) [ "amdgpu" ];

    environment.systemPackages = [ pkgs.nvidia-container-toolkit ];
    hardware = {
      graphics = {
        enable = true;
        enable32Bit = true;
      };
      amdgpu.opencl.enable = true;
      amdgpu.initrd.enable = true;

      nvidia-container-toolkit.enable = config.enable.nvidia-host;
      nvidia = lib.mkIf config.enable.nvidia-host {
        modesetting.enable = true;
        powerManagement.enable = false;
        powerManagement.finegrained = false;
        open = false;
        nvidiaSettings = true;
        package = config.boot.kernelPackages.nvidiaPackages.stable;
      };
    };

    boot.kernelModules =
      lib.optionals config.enable.nvidia-host [
        "nvidia"
        "nvidia_modeset"
        "nvidia_uvm"
        "nvidia_drm"
      ]
      ++ lib.optionals (!config.enable.nvidia-host) [
        "amdgpu"
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
      "nvidia-drm.modeset=1"
    ];
    boot.initrd.kernelModules = lib.optionals config.enable.nvidia-host [
      "nvidia"
      "nvidia_modeset"
      "nvidia_uvm"
      "nvidia_drm"
    ];
  };
}
