{ ... }:
{
  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "ahci"
    "usb_storage"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];
  boot.kernelParams = [
    "video=eDP-1:1920x1080@60"
    "video=HDMI-A-1:3440x1440@60"
    "mem_sleep_default=deep"
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  systemd.timers.firewall-start = {
    description = "Start firewall after boot";
    wantedBy = [ "timers.target" ];
    timerConfig.OnBootSec = "10s";
    timerConfig.Unit = "firewall.service";
  };
}
