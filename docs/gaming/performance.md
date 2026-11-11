# Performance — `gaming-performance`

`modules/features/gaming/performance.nix`. Option `gaming.performance`.

## What it sets, and why

- `programs.gamescope.enable` — the Vulkan/Wayland pre-loaded compositor
  games run under (frame pacing, integer scaling, HDR passthrough).
  `capSysNice = false` drops the set-capability that would let Gamescope
  renice processes itself; priority raising is gamemode's job, so the
  extra capability is unnecessary and left off.
- `programs.gamemode.enable` — the daemon that bumps scheduler priority,
  disables screensavers, and switches CPU profiles while a game is running.
- `mangohud` in systemPackages — the frame-timing overlay, driven per-launch
  (`mangohud %command` in Steam), so it's a package, not a service.
- `services.seatd.enable = false` — the seat daemon is explicitly off on
  gaming hosts (they log in through the display-manager path instead).

## Why the design

Three layers that stack at launch time — gamemode (host process policy),
Gamescope (per-game compositor), MangoHud (per-game overlay) — each with
the right packaging: two `programs.*` services plus one plain package.
