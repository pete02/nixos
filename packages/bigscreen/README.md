# plasma-bigscreen-flake

Plasma Bigscreen for NixOS 26.05 (Plasma 6.6), pinned to upstream commit
`6a32f4fb`, the last one requiring only Plasma >= 6.5.90.

**Status:** evaluates; not yet built or run.

## Use

```nix
# flake.nix inputs
plasma-bigscreen.url = "path:/path/to/plasma-bigscreen-flake"; # or your git URL
```

```nix
# host module
imports = [ inputs.plasma-bigscreen.nixosModules.default ];

programs.plasma-bigscreen.enable = true;
services.displayManager.sddm.enable = true;
services.displayManager.sddm.wayland.enable = true;
services.displayManager.defaultSession = "plasma-bigscreen-wayland";
users.users.<name>.extraGroups = [ "input" ];
```

The module builds with the host's `pkgs`. The flake's own `nixpkgs` input
is used by `packages` and `checks`.

## Outputs

- `packages.<system>.plasma-bigscreen` (`aarch64-linux`, `x86_64-linux`)
- `overlays.default`
- `nixosModules.default`
- `checks.<system>.plasma-bigscreen`

## Build

    nix build -L .#plasma-bigscreen

An x86_64 machine needs an aarch64 builder or emulation for
`.#packages.aarch64-linux.plasma-bigscreen`.
