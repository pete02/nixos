# Base apps — `base-apps`

`modules/features/base/apps.nix`. The human-use package bundles, gated by
three opt-in options. Unlike [settings](settings.md), every package here is
wrapped in `lib.mkIf`, so a host that enables none of these gets nothing.

## Options

- `common-tools.modeling` — 3D modeling tools.
- `common-tools.books` — e-book management.
- `common-tools.school` — note-taking / school tools.

The aggregator `base` is always imported, but these three flags default false,
so the module is inert until a host turns one on. Example: aria sets
`common-tools.books`.

## What each turns on

- **modeling** → `freecad` + `appimage-run`. `appimage-run` is there because
  FreeCAD and other CAD tools are often distributed as AppImages, which need a
  FUSE/AppImage runner on NixOS.
- **books** → `calibre`.
- **school** → Obsidian (override: `commandLineArgs = ["--ozone-platform=wayland"]`)
  plus `wineWow64Packages.waylandFull`.

## Why the overrides

- **Obsidian `--ozone-platform=wayland`**: Obsidian is a Chromium/Ozone app.
  Forcing the Wayland platform makes it render natively under the Wayland
  compositors these hosts run (Hyprland/bigscreen), instead of falling back to
  XWayland. Matches the fleet's `NIXOS_OZONE_WL="0"` policy in the shells
  services module — Ozone is opted into per-app, not globally, so this app
  carries its own flag.
- **`wineWow64Packages.waylandFull`**: the full Wine build with 64-bit Windows
  support and Wayland display, so Windows-only note/ebook tools run on the
  same Wayland sessions. Cross-link: `gaming/compatibility.nix` uses the
  related `waylandFull` Wine variant for the same Wayland reason.

Nothing here is secret or host-specific — these are plain desktop conveniences
turned on where a person actually uses them.
