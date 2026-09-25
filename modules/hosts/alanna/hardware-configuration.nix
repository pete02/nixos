{inputs, ...}: {
  flake.nixosModules.alannaHardware = {modulesPath, ...}: {
    imports = with inputs.nixos-raspberrypi.nixosModules; [
      raspberry-pi-5.base
      raspberry-pi-5.page-size-16k
      raspberry-pi-5.display-vc4
      raspberry-pi-5.bluetooth
      sd-image
    ];

    boot.loader.raspberry-pi.bootloader = "kernel";
    fileSystems."/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
    };
  };
}
