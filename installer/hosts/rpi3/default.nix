# Raspberry Pi 3 (64-bit). Image-based: build the SD image of this exact system and flash it.
{ lib, modulesPath, ... }:
{
  imports = [
    "${modulesPath}/installer/sd-card/sd-image-aarch64.nix"
    ../../modules/base.nix
  ];

  networking.hostName = "rpi3";
  nixpkgs.hostPlatform = "aarch64-linux";
  hardware.enableRedistributableFirmware = true;

  # Only 1 GB RAM.
  zramSwap.enable = true;
}
