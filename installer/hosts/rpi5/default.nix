# Raspberry Pi 5 via nvmd/nixos-raspberrypi (mainline nixpkgs support for Pi 5 is incomplete).
{ lib, nixos-raspberrypi, ... }:
{
  imports = [ ../../modules/base.nix ] ++ (with nixos-raspberrypi.nixosModules; [
    raspberry-pi-5.base
    raspberry-pi-5.display-vc4
    sd-image
  ]);

  networking.hostName = "rpi5";
  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
