{
  inputs,
  ...
}: {
  flake.nixosModules.alannaHardware = {
    lib,
    pkgs,
    ...
  }: {
    imports = [
      inputs.nixos-hardware.nixosModules.raspberry-pi-5
    ];

    # rpi5 boots via u-boot + extlinux, not grub
    boot.loader.grub.enable = false;
    boot.loader.generic-extlinux-compatible.enable = true;

    hardware.enableRedistributableFirmware = true;

    # Adjust label/device to match how you'll partition the SD card/NVMe
    fileSystems."/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
    };
  };
}