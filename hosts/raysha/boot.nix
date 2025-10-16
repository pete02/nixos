{ lib, pkgs, ... }:
{
  systemd.services."systemd-networkd-wait-online".enable = lib.mkForce false;

  systemd.timers.firewall-start = {
    description = "Start firewall after boot";
    wantedBy = [ "timers.target" ];
    timerConfig.OnBootSec = "10s";
    timerConfig.Unit = "firewall.service";
  };
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "ahci"
    "usbhid"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [
    "nvidia"
    "nvidia_modeset"
    "nvidia_uvm"
    "nvidia_drm"
  ];
  boot.kernelParams = [
    "drm.edid_firmware=DP-2:/boot/edid/monitor.bin"
    "nvidia-drm.modeset=1"
    "nvidia_drm.modeset=1"
    "nvidia.NVreg_UseVBiosModeset=1"
    "nvidia.NVreg_RegistryDwords=EnablePrimaryDisplay=1"
    "video=3440x1440@175"
  ];
  boot.blacklistedKernelModules = [ "amdgpu" ];
  boot.extraModulePackages = [ ];
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
    timeout = 1;
  };

}
