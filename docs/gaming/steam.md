# Steam — `gaming-steam`

`modules/features/gaming/steam.nix`. Option `gaming.steam`.

## What it sets, and why

- `programs.steam.enable` — the NixOS option that pulls in the whole
  Steam runtime (the 32-bit multiarch bits, udev rules, the setuid
  launcher), not just the binary. `gamescopeSession.enable` adds the
  `steam-native`-style session wrapper so Steam launches through Gamescope
  where wanted.
- `nixpkgs.config.packageOverrides` re-derives `pkgs.steam` with an
  `extraPkgs` list — `libXi`, `libXinerama`, `libXScrnSaver`, `libpng`,
  `libpulseaudio`, `libvorbis`, `stdenv.cc.cc.lib`, `libkrb5`,
  `keyutils`, `winetricks` grafted into Steam's closure. Steam's own
  runtime misses these libraries for games and tools that dlopen them
  (PulseAudio-backed games, Vorbis audio, Kerberos-signed
  downloads, `winetricks` invocations); the override is how the packaging
  bug is patched instead of installing them system-wide and hoping Steam
  finds them.

## Why the design

One option, two mechanisms: the distro's `programs.steam` handles the
platform plumbing, while the package override fixes the closure of the
*package* itself — the only place the launcher's dependency list can be
corrected.
