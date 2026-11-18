{
  pkgs,
  lib,
  modulesPath,
  self,
  settings,
  ...
}: {
  imports = ["${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix" ../_base.nix];

  nixpkgs.hostPlatform = "x86_64-linux";
  image.fileName = lib.mkForce "nixos-installer-x86_64.iso";
  nix.settings.experimental-features = ["nix-command" "flakes"];

  users.users.root.openssh.authorizedKeys.keys = settings.sshKeys;
  users.users.nixos.openssh.authorizedKeys.keys = settings.sshKeys;

  # The wrapper embeds this whole flake's source, so it ships on the ISO.
  environment.systemPackages = [
    self.packages.${pkgs.stdenv.hostPlatform.system}.installer
    pkgs.git
    pkgs.gptfdisk
    pkgs.parted
    pkgs.vim
  ];
}
