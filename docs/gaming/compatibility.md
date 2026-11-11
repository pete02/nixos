# Compatibility — `gaming-compatibility`

`modules/features/gaming/compatibility.nix`. Option `gaming.compatibility`.

## What it sets, and why

Enabling it only installs packages — there is no service plumbing, the
tools are run per-game:

- `steam-run` — a wrapper that runs arbitrary commands inside Steam's
  multiarch runtime environment, used to launch non-Steam binaries with the
  right 32-bit libs.
- `wineWow64Packages.waylandFull` — the Wine build with 64-bit Windows
  support and Wayland enabled, the variant the fleet actually wants rather
  than the default X11-only Wine.
- `protonup-ng` — fetches and installs Proton-7/F3C builds into
  `~/.local/share/steam`.
- `lutris` and `umu-launcher` — the two launchers that resolve a game into
  the right Wine/Proton prefix (UMU is the standards-based launcher Steam
  and other front-ends are adopting).

## Why the design

A pure package list because compatibility is chosen per game at launch
time, not configured globally; the only judgement in it is picking the
Wayland-enabled 64-bit Wine build, which matches the fleet's Wayland
desktops.
