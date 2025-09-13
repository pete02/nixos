{ ... }:
{
  imports = [
    ./desktops/qtile.nix
    ./desktops/hyprland.nix
    ./localization.nix
    ./dev.nix
    ./school.nix
    ./batterymanagement.nix
    ./apps/apps.nix
    ./nixos-management.nix
    ./nvidia.nix
  ];
}
