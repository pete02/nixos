{ lib, settings, nixos-raspberrypi, ... }:
{
  imports = [ ../_base.nix ] ++ (with nixos-raspberrypi.nixosModules; [
    raspberry-pi-5.base
    raspberry-pi-5.display-vc4
    sd-image
  ]);

  networking.hostName = "rpi5";
  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";

  services.openssh.settings.PasswordAuthentication = lib.mkForce true;
  users.users.${settings.username}.initialPassword = lib.mkForce settings.initialPassword;
}
