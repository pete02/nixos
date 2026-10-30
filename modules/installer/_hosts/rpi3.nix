{
  lib,
  modulesPath,
  ...
}: {
  imports = [
    "${modulesPath}/installer/sd-card/sd-image-aarch64.nix"
    ../_base.nix
  ];
  
  networking.hostName = "rpi3";
  nixpkgs.hostPlatform = "aarch64-linux";
  hardware.enableRedistributableFirmware = true;
  zramSwap.enable = true;
}
