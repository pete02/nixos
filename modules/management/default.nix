{ ... }:
{
  imports = [
    ./batterymanagement.nix
    ./bluetooth.nix
    ./localization.nix
    ./nixos-management.nix
    ./hostgpus
    ./user.nix
    ./wireless.nix
    ./networking.nix
  ];
}
