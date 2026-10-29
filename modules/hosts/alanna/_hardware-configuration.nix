{
  lib,
  nixos-raspberrypi,
  ...
}: {
  imports = with nixos-raspberrypi.nixosModules; [
    raspberry-pi-5.base
    raspberry-pi-5.display-vc4 # drop if headless and you don't need it
  ];

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";

  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
    options = ["noatime"];
  };

  fileSystems."/boot/firmware" = {
    device = "/dev/disk/by-label/FIRMWARE";
    fsType = "vfat";
    options = ["noatime" "noauto" "x-systemd.automount" "x-systemd.idle-timeout=1min"];
  };

  swapDevices = [];

  # SSD is on USB (sda), so these are what the initrd needs.
  # usb_storage/uas/xhci_pci are already set in your rpi module.
  boot.initrd.availableKernelModules = ["usb_storage" "uas" "xhci_pci"];
}