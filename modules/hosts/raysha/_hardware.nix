{
  lib,
  config,
  ...
}: {
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/b4f514aa-cb46-4704-aab9-9f73a6e17eef";
    fsType = "ext4";
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/585C-CE71";
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

  zramSwap = {
    enable = true;
  };

  boot.kernelParams = [
    "cfg80211.ieee80211_regdom=FI"
    "iwlwifi.lar_disable=1"
  ];

  boot.extraModprobeConfig = ''
    options iwlwifi 11n_disable=8
  '';

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  hardware.enableRedistributableFirmware = true;
  hardware-gpus.nvidia = true;
  peripherals.logitech = true;
  hardware.mdadm = true;
  hardware.cachyos-kernel = true;
  system.stateVersion = "25.05";
}
