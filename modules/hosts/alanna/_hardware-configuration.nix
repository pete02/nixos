{
  lib,
  inputs,
  config,
  ...
}: {
  imports = with inputs.nixos-raspberrypi.nixosModules; [
    raspberry-pi-5.base
    raspberry-pi-5.display-vc4 # drop if headless and you don't need it
  ];

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
  boot.loader.raspberry-pi.bootloader = "kernel";
  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
    options = ["noatime"];
  };
  powerManagement.cpuFreqGovernor = "performance";
  fileSystems."/boot/firmware" = {
    device = "/dev/disk/by-label/FIRMWARE";
    fsType = "vfat";
    options = ["noatime" "noauto" "x-systemd.automount" "x-systemd.idle-timeout=1min"];
  };

  boot.extraModprobeConfig = ''
    options iwlwifi power_save=0
    options iwlmvm power_scheme=1
    options cfg80211 ieee80211_regdom="FI"
  '';

  hardware.raspberry-pi.config.all.dt-overlays.disable-wifi = {
    enable = true;
    params = {};
  };
  swapDevices = [];
  hardware.graphics.enable = true;
  users.users.${config.username}.extraGroups = lib.mkAfter ["uinput" "video" "render" "input"];

  # SSD is on USB (sda), so these are what the initrd needs.
  # usb_storage/uas/xhci_pci are already set in your rpi module.
  boot.initrd.availableKernelModules = ["usb_storage" "uas" "xhci_pci"];
}
