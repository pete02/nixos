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
  devices = [
    "10de:2704" # Nvidia 2060 mobile GPU
    "10de:22bb" # Nvidia audio controller
  ];
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
  boot.kernelModules = [
    #"nvidia"
    #"nvidia_modeset"
    #"nvidia_uvm"
    #"nvidia_drm"
    "vfio_pci"
    "vfio"
    "vfio_iommu_type1"
  ];
  boot.kernelParams = [
    "drm.edid_firmware=DP-2:/boot/edid/monitor.bin"
    "nvidia-drm.modeset=1"
    "nvidia_drm.modeset=1"
    "nvidia.NVreg_UseVBiosModeset=1"
    "nvidia.NVreg_RegistryDwords=EnablePrimaryDisplay=1"
    "video=3440x1440@175"
    "vfio-pci.ids=${lib.concatStringsSep "," devices}"
  ];
  boot.blacklistedKernelModules = [
    "amdgpu"
    "kvm"
    "kvm_amd"
    "nouveau"
    "nvidia"
    "nvidia_drm"
    "nvidia_modeset"
    "i2c_nvidia_gpu"
  ];

  boot.extraModprobeConfig = ''
    softdep nvidia pre: vfio-pci
    softdep drm pre: vfio-pci
    softdep nouveau pre: vfio-pci
  '';

  virtualisation.spiceUSBRedirection.enable = true;
  boot.extraModulePackages = [ ];
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
    timeout = 1;
  };
  boot.swraid.enable = true;

}
