# Graphics — `gaming-graphics`

`modules/features/gaming/graphics.nix`. Option `gaming.graphics`.

## What it sets, and why

Installs two packages and nothing else:

- `mesa-demos` — the Mesa demo binaries (`glxinfo`, `glxgears`, etc.) used
  to check which GL driver and which GPU a machine actually ended up with
  after all the `hardware-gpus` blacklisting and kernel params are applied.
- `dejavu_fonts` — a font set games and launchers assume is present; some
  titles fall back to missing-glyph boxes when it isn't.

## Why the design

Small utilities that are only wanted on play machines — diagnostic tooling
plus one compatibility font — so they're an opt-in rather than always
installed.
