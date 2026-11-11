# `mkScript` — the checked-script builder (`lib/scripts.nix`)

Leaf doc. Every executable in this repo that ships to a machine is built
through `self.lib.mkScript`. This is why; the pattern is load-bearing.

## The signature

```nix
config.flake.lib.mkScript = pkgs: { name, src, runtimeInputs ? [],
  substitutions ? {}, checkSetup ? "" }: ...
```

- **`pkgs` is curried in** because each call site picks its own package set
  (stable vs. the host's `pkgs`); the builder itself stays package-agnostic.
- **`src`** is a *file in the repo* (`./scripts/foo.sh`), not a string — the
  script stays readable and editable in the tree; Nix reads it at build time.
- **`substitutions`** injects `@KEY@` placeholders: `lib.replaceStrings` maps
  `@KEY@` → value before the script is written. That's how host-specific data
  (repository URL, ntfy topic, cache URL, keep-count) gets baked in — the
  script in the repo stays generic, the built script is concrete.
- **`checkSetup`** exists for scripts whose real environment only exists at
  runtime: healthcheck's mdadm script, for instance, runs against a fake
  `/sys` tree (`export SYS="$TMPDIR/sys"; mkdir -p "$SYS/block"`) so `--check`
  can run at build time where no RAID array exists.

## The two-stage build

```nix
pkgs.writeShellApplication { inherit name runtimeInputs; text = ...; }
# then
pkgs.runCommand "${name}-checked" { executable = true; } ''
  ${checkSetup}
  # Empty PATH: only runtimeInputs are visible, so the script's
  # own check() proves every command it needs was declared.
  env -i PATH=/var/empty ${script}/bin/${name} --check
''
```

1. **`writeShellApplication`** is the shellcheck-checked wrapper: `runtimeInputs`
   become the script's store-path dependencies, so the script's `#!` environment
   is *exactly* those packages.
2. **The `runCommand` runs the script with `--check` at build time** with an
   empty environment (`env -i PATH=/var/empty`). Two verbatim comments carry
   the reasoning:
   - *Empty PATH means the script's own `check()` proves every command it needs
     was declared in `runtimeInputs`* — if the script calls `curl` but `curl`
     isn't in `runtimeInputs`, the build fails, because at check time `curl`
     isn't on PATH. Undeclared dependencies are caught at build time, not at
     03:00 on a Sunday.
   - *`checkSetup` runs first* to fake whatever the script's `check()` needs
     from the world.
   - Every script in the repo therefore carries a `check()` function
     (`command -v hyprctl`-style probes). That contract is *enforced* by this
     builder — a script without `check()` can never build.

## Output shape

```nix
''
ln -s $script/bin/${name} $out/bin/${name}
''
```

The final derivation's `bin/<name>` is a symlink into the checked script's
store path. Consumers use it in systemd units as an **absolute store-pinned
path** (`"${script}/bin/${name}"`), which is why the nixos-management and
healthcheck modules write `ExecStart = "${...}/bin/foo"`: the ExecStart path
changes exactly when the script content changes — that's the mechanism by which
rebuilding a host restarts the services running the new script.
