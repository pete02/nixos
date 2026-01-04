{
  lib,
  pkgs,
  inputs,
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
    extraKernelPackages = pkgs.linuxPackages_latest;
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
    };
    swraid.enable = true;
  };
}
