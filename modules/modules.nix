{ ... }:
{
  imports = [
    ./desktops/qtile.nix
    ./desktops/hyprland.nix
    ./management/localization.nix
    ./dev.nix
    ./school.nix
    ./management/batterymanagement.nix
    ./apps/apps.nix
    ./management/nixos-management.nix
    ./management/nvidia.nix
    ./management/user.nix
  ];
}
