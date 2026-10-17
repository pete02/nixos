{
  lib,
  config,
  ...
}: {
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/BDEA-EDC0";
    fsType = "vfat";
    options = ["fmask=0022" "dmask=0022"];
  };

  swapDevices = [];
  boot.blacklistedKernelModules = ["r8169" "hid_logitech_hidpp"];

  boot.loader = {
    systemd-boot.enable = true;
    systemd-boot.configurationLimit = 5;
    efi.canTouchEfiVariables = true;
    timeout = 1;
  };
  boot.swraid = {
    enable = true;
    mdadmConf = ''
      MAILADDR petrik.rasanen@gmail.com
    '';
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  hardware.enableRedistributableFirmware = true;
  peripherals.nvidia = true;
  peripherals.logitech = true;
  hardware.mdadm = true;
  hardware.cachyos-kernel = true;
  system.stateVersion = "25.05";
}
