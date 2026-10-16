{...}: {
  flake.nixosModules.hardware-gpus = {
    lib,
    pkgs,
    config,
    ...
  }: let
    cfg = config.peripherals;

    nvidiaKernelModules = [
      "nvidia"
      "nvidia_modeset"
      "nvidia_uvm"
      "nvidia_drm"
    ];

    # Settings shared by every GPU vendor.
    commonGraphics = {
      hardware.graphics = {
        enable = true;
        enable32Bit = true;
      };
    };

    # Everything the stable and legacy NVIDIA setups have in common;
    # only the driver package differs.
    mkNvidiaConfig = package:
      lib.mkMerge [
        commonGraphics
        {
          services.xserver.videoDrivers = ["nvidia"];

          environment.systemPackages = [pkgs.nvidia-container-toolkit];

          hardware = {
            nvidia-container-toolkit.enable = true;
            nvidia = {
              inherit package;
              modesetting.enable = true;
              powerManagement.enable = false;
              powerManagement.finegrained = false;
              open = false;
              nvidiaSettings = true;
            };
          };

          boot = {
            kernelModules = nvidiaKernelModules;
            kernelParams = ["nvidia-drm.modeset=1"];
            blacklistedKernelModules = ["amdgpu"];
            initrd.kernelModules = nvidiaKernelModules;
          };
        }
      ];
  in {
    options.peripherals = {
      # GPU (mutually exclusive, enforced by the assertions below)
      nvidia = lib.mkEnableOption "NVIDIA GPU (stable driver)";
      nvidia-legacy = lib.mkEnableOption "NVIDIA GPU (legacy driver for GTX 900/1000 series)";
      amd = lib.mkEnableOption "AMD GPU";
    };

    config = lib.mkMerge [
      {
        assertions = [
          {
            assertion =
              lib.count lib.id [cfg.nvidia cfg.nvidia-legacy cfg.amd] <= 1;
            message = "peripherals: only one of `nvidia`, `nvidia-legacy` and `amd` can be enable at a time.";
          }
        ];
      }

      # ── GPUs ────────────────────────────────────────────────────────────
      (lib.mkIf cfg.nvidia
        (mkNvidiaConfig config.boot.kernelPackages.nvidiaPackages.stable))

      (lib.mkIf cfg.nvidia-legacy
        (mkNvidiaConfig config.boot.kernelPackages.nvidiaPackages.legacy_580))

      (lib.mkIf cfg.amd (lib.mkMerge [
        commonGraphics
        {
          services.xserver.videoDrivers = ["amdgpu"];

          hardware.amdgpu = {
            opencl.enable = true;
            initrd.enable = true;
          };

          boot = {
            kernelModules = ["amdgpu"];
            blacklistedKernelModules = nvidiaKernelModules;
          };
        }
      ]))
    ];
  };
}
