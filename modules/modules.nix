{ ... }:
{
  imports = [
    ./desktops/qtile.nix
    ./desktops/hyprland.nix
    ./dev.nix
    ./school.nix
    ./apps/apps.nix
    ./management/batterymanagement.nix
    ./management/localization.nix
    ./management/nixos-management.nix
    ./management/nvidia.nix
    ./management/user.nix
    ./gaming.nix
    ./management/wireless.nix
  ];
}
