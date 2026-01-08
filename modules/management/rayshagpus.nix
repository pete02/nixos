{
  config,
  lib,
  pkgs,
  inputs,
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
    inputs.nixpkgs.overlays = [
      (final: prev: {
        linux-firmware = prev.linux-firmware.overrideAttrs (old: rec {
          version = "20250509";
          src = prev.fetchzip {
            url = "https://cdn.kernel.org/pub/linux/kernel/firmware/linux-firmware-${version}.tar.xz";
            hash = "sha256-0FrhgJQyCeRCa3s0vu8UOoN0ZgVCahTQsSH0o6G6hhY=";
          };
        });
      })
    ];
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
      "drm.edid_firmware=DP-2:/boot/edid/monitor.bin"
      "nvidia-drm.modeset=1"
      "nvidia_drm.modeset=1"
      "nvidia.NVreg_UseVBiosModeset=1"
      "nvidia.NVreg_RegistryDwords=EnablePrimaryDisplay=1"
      "video=3440x1440@175"
    ];
  };
}
