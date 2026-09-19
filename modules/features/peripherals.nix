{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.peripherals = {
    lib,
    pkgs,
    config,
    ...
  }: {
    options = {
      # GPU Options (mutually exclusive)
      peripherals.nvidia = lib.mkEnableOption "NVIDIA GPU (stable driver)";
      peripherals.nvidia-legacy = lib.mkEnableOption "NVIDIA GPU (legacy driver for GTX 900/1000 series)";
      peripherals.amd = lib.mkEnableOption "AMD GPU (auto-enabled when no NVIDIA)";

      # Peripheral Options
      peripherals.logitech = lib.mkEnableOption "Logitech device support (logiops, piper, ratbagd)";
      peripherals.razer = lib.mkEnableOption "Razer device support (RGB lighting control)";
    };

    config = lib.mkMerge [
      # NVIDIA Stable GPU
      (lib.mkIf config.peripherals.nvidia {
        services.xserver.videoDrivers = ["nvidia"];

        environment.systemPackages = [pkgs.nvidia-container-toolkit];

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
        boot.blacklistedKernelModules = ["amdgpu"];
        boot.kernelParams = ["nvidia-drm.modeset=1"];
        boot.initrd.kernelModules = [
          "nvidia"
          "nvidia_modeset"
          "nvidia_uvm"
          "nvidia_drm"
        ];
      })

      # NVIDIA Legacy GPU (GTX 900/1000 series)
      (lib.mkIf config.peripherals.nvidia-legacy {
        services.xserver.videoDrivers = ["nvidia"];

        environment.systemPackages = [pkgs.nvidia-container-toolkit];

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
        boot.blacklistedKernelModules = ["amdgpu"];
        boot.kernelParams = ["nvidia-drm.modeset=1"];
        boot.initrd.kernelModules = [
          "nvidia"
          "nvidia_modeset"
          "nvidia_uvm"
          "nvidia_drm"
        ];
      })

      # AMD GPU (auto-enabled when no NVIDIA)
      (lib.mkIf config.peripherals.amd {
        services.xserver.videoDrivers = ["amdgpu"];

        hardware = {
          graphics = {
            enable = true;
            enable32Bit = true;
          };
          amdgpu.opencl.enable = true;
          amdgpu.initrd.enable = true;
        };

        boot.kernelModules = ["amdgpu"];
        boot.blacklistedKernelModules = [
          "nvidia"
          "nvidia_modeset"
          "nvidia_uvm"
          "nvidia_drm"
        ];
      })

      # Logitech Device Support
      (lib.mkIf config.peripherals.logitech {
        environment.systemPackages = with pkgs; [
          logiops
          piper
          libratbag
        ];

        hardware.logitech.wireless.enable = true;

        services.ratbagd.enable = true;
      })

      # Razer Device Support (RGB lighting)
      (lib.mkIf config.peripherals.razer {
        environment.systemPackages = with pkgs; [
          openrazer-daemon
          polychromatic
        ];

        users.users.${config.username} = {
          extraGroups = ["openrazer"];
        };
      })
    ];
  };
}
