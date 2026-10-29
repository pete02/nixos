{lib,inputs,...}: {

  imports = with inputs.nixos-raspberrypi.nixosModules; [
    raspberry-pi-3.base # check the exact attr name in your nixos-raspberrypi revision
  ];
  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
  boot.loader.raspberry-pi.bootloader = "kernel";
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

  fileSystems."/data" = {
    device = "/dev/disk/by-label/NIXOS_HDD";
    fsType = "ext4";
    options = ["nofail" "x-systemd.automount" "x-systemd.device-timeout=120"];
  };
}
