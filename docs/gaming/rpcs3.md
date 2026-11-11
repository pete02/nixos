# RPCS3 — `gaming-rpcs3`

`modules/features/gaming/rpcs3.nix`. Option `gaming.rpcs3`. The same file
also defines `flake.packages.x86_64-linux.rpcs3` — the emulator is a
flake *package*, not an ordinary nixpkgs dependency.

## What it sets, and why

- `environment.systemPackages` gets
  `self.packages.${pkgs.stdenv.hostPlatform.system}.rpcs3` — the locally
  defined package, so the host runs exactly the build this flake produces.
  The package is built against `nixpkgs-stable` with an
  `allowUnfreePredicate` allowing only `rpcs3` itself.
- The package overrides `pkgs.rpcs3`'s sources: its `src` and every
  bundled third-party dependency (7-Zip, asmjit, Fusion, wolfSSL,
  yaml-cpp, SoundTouch, stb, gamemode) are `fetchFromGitHub` calls pinned
  to exact commits, swapped into the build tree in `postPatch`. The
  package meta says *"RPCS3 package with fixed reachable submodule
  revisions"* — upstream RPCS3 tracks its 3rdparty deps as git
  submodules floating on whatever the remotes point at, which makes builds
  unreproducible and breaks whenever an upstream repo force-pushes or
  moves; pinning each revision is what makes the build hermetic.
- `postInstall` copies Liberation Sans into the package's own font
  directory as `Arial.ttf` / `arial.ttf` — RPCS3's UI hardcodes Arial, and
  Liberation is its metric-compatible stand-in, so the emulator renders
  correctly without a proprietary font (`liberation_ttf` is a propagated
  dependency for the same reason).
- A oneshot `systemd.services.rpcs3-savegames` runs as the desktop user:
  it symlinks RPCS3's savedata path
  (`~/.config/rpcs3/dev_hdd0/home/00000001/savedata`) to
  `~/savegames/rpcs3`, moving any existing saves over first — verbatim
  comment: *"Keep RPCS3's savedata in ~/savegames/rpcs3 by symlinking it
  there. Existing saves are moved over first, so nothing is lost."* The
  stable location is where the fleet's sync tooling can see saves, instead
  of them hiding in a deep config path.

## Why the design

RPCS3 is vendored because its upstream packaging is unstable — the pinned
revisions are the fix, and `version = "0.0.40-fixed"` names the result
distinctly from nixpkgs' moving package. The savegames service is needed
because the emulator's save path is hardcoded and versioned by game data,
so redirection has to happen at runtime in the user's home, which only a
user-scoped oneshot can do.
