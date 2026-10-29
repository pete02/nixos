{ ... }: {
    "/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
      options = ["noatime"];
    };



  boot.initrd.availableKernelModules = [
    "usb_storage"
    "uas"
    "xhci_pci"
  ];
}