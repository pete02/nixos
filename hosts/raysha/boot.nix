{
  lib,
  pkgs,
  inputs,
  system,
  ...
}:
let
  # Fetch/override the upstream kernel and patch it with CachyOS patches
  patchedKernel = pkgs.cachyosKernels.linux-cachyos-latest.override {
    pname = "linux-cachyos-with-custom-source";
    version = "6.18.3-cachyos";
    src = pkgs.fetchurl {
      url = "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.18.3.tar.xz";
      sha256 = "sha256sum_here";
    };
    # You can also add extra args if needed, e.g. `extraPatches = [...]`
  };

  # Wrap in linuxPackages function for NixOS internal `.extend` calls
  cachyosLinuxPackages = self: super: {
    linuxPackages = super.linuxPackages // {
      kernel = patchedKernel;
      headers = patchedKernel.dev; # headers for modules
      modules = patchedKernel; # modules for NixOS to include
    };
  };

  # Import pkgs with overlay applied
  pkgsWithOverlay = import <nixpkgs> {
    inherit (pkgs) system;
    overlays = [ cachyosLinuxPackages ];
    config = {
      allowUnfree = true;
    };
  };
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

  boot.kernelPackages = pkgs.cachyosKernels.linux-cachyos-latest;

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
  boot.swraid.enable = true;

}
