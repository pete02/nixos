{ pkgs, ... }:
{
  boot.kernelModules = [
    "nvidia"
    "nvidia_modeset"
    "nvidia_uvm"
    "nct6775"
    "nvidia_drm"
    "kvm-amd"
  ];
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ahci"
    "usb_storage"
    "usbhid"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.extraModulePackages = [ ];
  boot.postBootCommands = ''
    ${pkgs.hdparm}/bin/hdparm -B 255 /dev/disk/by-id/wwn-0x5000c500f6ff664b
    ${pkgs.hdparm}/bin/hdparm -B 255 /dev/disk/by-id/wwn-0x5000c500662713d6
  '';
}
