# Gaming — `gaming`

`modules/features/gaming/default.nix` imports five submodules:
`gaming-steam`, `gaming-performance`, `gaming-compatibility`,
`gaming-rpcs3`, `gaming-graphics`.

Every host inherits the aggregator through the fleet's fixed feature list,
but each submodule is inert until its option is enabled, so only the
machines meant for play (aria, raysha) actually carry any of it. The
grouping exists because "gaming" is a stack of independent layers — the
client (Steam), the performance harness (gamemode/Gamescope/MangoHud), the
compatibility runtimes (Wine/Proton launchers), a specific emulator
(RPCS3), and small graphics utilities — each switchable on its own rather
than one monolith.

- [Steam](gaming/steam.md) — `programs.steam` plus a patched Steam package
  with extra runtime libraries.
- [Performance](gaming/performance.md) — Gamescope, gamemode, MangoHud.
- [Compatibility](gaming/compatibility.md) — Wine, Proton, Lutris, UMU.
- [RPCS3](gaming/rpcs3.md) — the PS3 emulator, vendored with pinned
  submodules, plus a savedata redirect.
- [Graphics](gaming/graphics.md) — Mesa demos and a font set.
