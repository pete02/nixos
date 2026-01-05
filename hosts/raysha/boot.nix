{
  lib,
  pkgs,
  inputs,
  config,
  ...
}:
let
  # Patched CachyOS kernel
  patchedKernel = inputs.nix-cachyos-kernel.packages.x86_64-linux.linux-cachyos-latest-zen4.override {

    # src = pkgs.fetchurl { url = "..."; sha256 = "..."; };
    # extraPatches = [...];  # optional
  };

  # Generate a proper NixOS kernelPackages set
  patchedKernelPackages = pkgs.linuxPackagesFor patchedKernel;
in
{

  systemd.services."systemd-networkd-wait-online".enable = lib.mkForce false;

  systemd.timers.firewall-start = {
    description = "Start firewall after boot";
    wantedBy = [ "timers.target" ];
    timerConfig.OnBootSec = "10s";
    timerConfig.Unit = "firewall.service";
  };

  nix.settings.substituters = [ "https://attic.xuyh0120.win/lantian" ];
  nix.settings.trusted-public-keys = [ "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc=" ];

  boot.kernelPackages = patchedKernelPackages;

  #boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "ahci"
    "usbhid"
    "usb_storage"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];

  boot.extraModulePackages = [ ];
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
    timeout = 1;
  };
  boot.swraid.enable = true;

}
