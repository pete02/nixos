# `nixos-installer install` writes ../_hardware/x86.nix; until then fall back to labels
# so the config still evaluates.
{ lib, ... }:
let hasHw = builtins.pathExists ../_hardware/x86.nix;
in
{
  imports = [ ../_base.nix ] ++ lib.optional hasHw ../_hardware/x86.nix;

  networking.hostName = "x86";
  nixpkgs.hostPlatform = "x86_64-linux";
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  hardware.enableRedistributableFirmware = true;

  fileSystems = lib.mkIf (!hasHw) {
    "/" = { device = "/dev/disk/by-label/nixos"; fsType = "ext4"; };
    "/boot" = { device = "/dev/disk/by-label/NIXOS_BOOT"; fsType = "vfat"; options = [ "umask=0077" ]; };
  };
}
