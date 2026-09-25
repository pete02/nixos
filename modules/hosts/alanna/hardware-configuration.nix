{inputs, ...}: {
  flake.nixosModules.alannaHardware = {
    lib,
    pkgs,
    modulesPath,
    ...
  }: {
    imports = [
      inputs.nixos-hardware.nixosModules.raspberry-pi-5
      "${modulesPath}/installer/sd-card/sd-image-aarch64.nix"
    ];

    # rpi5 boots via u-boot + extlinux, not grub
    boot.loader.grub.enable = false;
    boot.loader.generic-extlinux-compatible.enable = true;

    hardware.enableRedistributableFirmware = true;
  };
}
