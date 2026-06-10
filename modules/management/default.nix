{ ... }:
{
  imports = [
    ./batterymanagement.nix
    ./bluetooth.nix
    ./localization.nix
    ./nixos-management.nix
    ./user.nix
    ./wireless.nix
    ./networking.nix
    ./nvidia-gpu.nix
    ./nvidia-gpu-legacy.nix
    ./amd-gpu.nix
  ];
}
