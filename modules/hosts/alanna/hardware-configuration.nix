{inputs, ...}: {
  flake.nixosModules.alannaHardware = {modulesPath, ...}: {
    imports = with inputs.nixos-raspberrypi.nixosModules; [
      raspberry-pi-5.base
      raspberry-pi-5.page-size-16k
      raspberry-pi-5.display-vc4
      raspberry-pi-5.bluetooth
    ];
    nixpkgs.overlays = [ inputs.nixos-raspberrypi.overlays.pkgs ];
    boot.loader.raspberry-pi.bootloader = "kernel";
    fileSystems."/" = {
      device = "/dev/disk/by-uuid/dedc855b-b0f4-4ebb-b15e-bed84eecf9ee";
      fsType = "ext4";
    };

    fileSystems."/boot/firmware" = {
      device = "/dev/disk/by-uuid/2175-794E";  # unchanged, still the SD card
      fsType = "vfat";
    };
    system.stateVersion = "26.05";
    swapDevices = [
      {
        device = "/swapfile";
        size = 8192; # MiB = 8GB
      }
  ];
  };
}
