# Target x86_64 UEFI machine. `nixos-installer install` writes hardware-configuration.nix
# next to this file; until then we fall back to the label-based layout the installer creates
# so the config still evaluates.
{ lib, ... }:
let hasHw = builtins.pathExists ./hardware-configuration.nix;
in
{
  imports = [ ../../modules/base.nix ] ++ lib.optional hasHw ./hardware-configuration.nix;

  networking.hostName = "x86";
  nixpkgs.hostPlatform = "x86_64-linux";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  hardware.enableRedistributableFirmware = true;

  fileSystems = lib.mkIf (!hasHw) {
    "/" = { device = "/dev/disk/by-label/nixos"; fsType = "ext4"; };
    "/boot" = {
      device = "/dev/disk/by-label/NIXOS_BOOT";
      fsType = "vfat";
      options = [ "umask=0077" ];
    };
  };
}
