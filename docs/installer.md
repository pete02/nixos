# Installer

NixOS images that bootstrap the fleet, plus the install tool that writes them
to disk. One flake part, three targets.

| Target | Image | Built by |
| --- | --- | --- |
| `x86` | ISO (`nixos-installer-x86_64.iso`) | `flake.nixosConfigurations.x86` |
| `rpi3` | SD image | `flake.nixosConfigurations.rpi3` |
| `rpi5` | SD image (via `nixos-raspberrypi`) | `flake.nixosConfigurations.rpi5` |

The images and the `nixos-installer` CLI are the *same* flake as the hosts —
the wrapper ships the whole repo on the ISO ([see why](installer/install.md)).

## How it fits together

- `modules/installer/default.nix` — the only flake part in this directory;
  declares `flake.nixosConfigurations`, the `installer` package, the
  `sd-rpi3`/`sd-rpi5` apps, and `apps.installer`.
- Everything else is `_`-prefixed (`_base.nix`, `_settings.nix`,
  `_package.nix`, `_hosts/*.nix`, `_hardware/*.nix`) so import-tree ignores it —
  the installer is *not* a `nixosModules` like the features; it is a
  `nixosConfigurations` peer of the hosts.

## Read the leaves

- [Images and their settings](installer/images.md) — what each image configures,
  and why (`_base`, `_settings`, the per-host image overlays, the
  `_hardware/x86.nix` fallback).
- [The install tool](installer/install.md) — `nixos-installer.sh`:
  `list`/`build`/`flash`/`install`, the device-safety checks, the UEFI-only
  partition layout, and how it hands off to `nixos-install`.
