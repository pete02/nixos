{ pkgs, lib, modulesPath, self, settings, ... }:
{
  imports = [ "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix" ];

  nixpkgs.hostPlatform = "x86_64-linux";
  isoImage.isoName = lib.mkForce "nixos-installer-x86_64.iso";

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # SSH into the live environment with your keys.
  users.users.root.openssh.authorizedKeys.keys = settings.sshKeys;
  users.users.nixos.openssh.authorizedKeys.keys = settings.sshKeys;

  # The installer wrapper embeds this flake's source, so it ships on the ISO.
  environment.systemPackages = [
    self.packages.${pkgs.stdenv.hostPlatform.system}.installer
    pkgs.git
    pkgs.gptfdisk
    pkgs.parted
    pkgs.vim
  ];
}
