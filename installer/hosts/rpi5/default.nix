# Raspberry Pi 5 via nvmd/nixos-raspberrypi (mainline nixpkgs support for Pi 5 is incomplete).
{ lib, settings, nixos-raspberrypi, ... }:
{
  imports = [ ../../modules/base.nix ] ++ (with nixos-raspberrypi.nixosModules; [
    raspberry-pi-5.base
    raspberry-pi-5.display-vc4
    sd-image
  ]);

  networking.hostName = "rpi5";
  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";

  # Always allow password SSH login on this image, even if settings.sshKeys is set.
  services.openssh.settings.PasswordAuthentication = lib.mkForce true;

  # Default password comes from settings.initialPassword ("changeme" unless you changed it).
  users.users.${settings.username}.initialPassword = lib.mkForce settings.initialPassword;
}
