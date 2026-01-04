{
  lib,
  pkgs,
  config,
  ...
}:
{
  systemd.services."systemd-networkd-wait-online".enable = lib.mkForce false;

  systemd.timers.firewall-start = {
    description = "Start firewall after boot";
    wantedBy = [ "timers.target" ];
    timerConfig.OnBootSec = "10s";
    timerConfig.Unit = "firewall.service";
  };

  boot = {
    kernelPackages = inputs.nix-cachyos-kernel.packages.x86_64-linux.linux-cachyos-latest-zen4;
    initrd.availableKernelModules = [
      "nvme"
      "xhci_pci"
      "ahci"
      "usbhid"
      "usb_storage"
      "sd_mod"
    ];
    initrd.kernelModules = [ ];
    kernelModules = [
      "nvidia"
      "nvidia_modeset"
      "nvidia_uvm"
      "nvidia_drm"
    ];
    kernelParams = [
      "drm.edid_firmware=DP-2:/boot/edid/monitor.bin"
      "nvidia-drm.modeset=1"
      "nvidia_drm.modeset=1"
      "nvidia.NVreg_UseVBiosModeset=1"
      "nvidia.NVreg_RegistryDwords=EnablePrimaryDisplay=1"
      "video=3440x1440@175"
    ];
    blacklistedKernelModules = [ "amdgpu" ];
    extraModulePackages = [ ];
    loader = {
      systemd-enable = true;
      efi.canTouchEfiVariables = true;
      timeout = 1;

      entries = [
        {
          name = "CachyOS Latest Zen4"; # primary kernel
          linuxKernel = inputs.nix-cachyos-kernel.packages.x86_64-linux.linux-cachyos-latest-zen4.kernel;
          initrd = inputs.nix-cachyos-kernel.packages.x86_64-linux.linux-cachyos-latest-zen4.initrd;
          options = "root=${config.boot.loader.efi.efiSysMountPoint}/nixos-root rw";
        }
        {
          name = "Linux LTS"; # fallback
          linuxKernel = pkgs.linuxPackages_latest.kernel; # or linux-lts if you prefer
          initrd = pkgs.linuxPackages_latest.initrd;
          options = "root=${config.boot.loader.efi.efiSysMountPoint}/nixos-root rw";
        }
      ];
    };
    swraid.enable = true;
  };
}
