{ pkgs, ... }:
{
  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "ahci"
    "usb_storage"
    "sd_mod"
  ];
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];
  boot.kernelParams = [
    "video=eDP-1:1920x1080@60"
    "mem_sleep_default=deep"
    "iwlwifi.regdom=FI"
    "amdgpu.dc=1"
  ];
  boot.blacklistedKernelModules = [ "hid_logitech_hidpp" ];
  boot.extraModprobeConfig = "options cfg80211 ieee80211_regdom=FI";
  # Use the systemd-boot EFI boot loader.
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
    timeout = 1;
  };

  systemd.timers.firewall-start = {
    description = "Start firewall after boot";
    wantedBy = [ "timers.target" ];
    timerConfig.OnBootSec = "10s";
    timerConfig.Unit = "firewall.service";
  };

  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc
      zlib
      glibc
      libgcc
      libstdcxx5
      libffi
      openssl
    ];
  };
}
