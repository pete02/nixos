# Host table and host constructors (`lib/hosts.nix`)

Leaf doc: this explains how the fleet's host definitions work and why each
piece is shaped the way it is.

## The table (`rawHosts`)

```nix
rawHosts = {
  aria.buildServer = true;
  raysha.buildServer = true;
  talia.sshServer = true;
  eris   = { rpi = true; sshServer = true; };
  alanna = { rpi = true; sshServer = true; };
};
```

One entry per machine, with three booleans that mean different things:

| Flag | Meaning | Who has it |
|---|---|---|
| `buildServer` | This machine is offered as a remote `nix-build` target | aria, raysha |
| `sshServer` | This machine is sshed *into* by other fleet hosts (needs a host key + known_hosts entry) | talia, eris, alanna — plus anything with `buildServer` |
| `rpi` | Built with the Raspberry-OS toolchain, not plain `nixosSystem` | eris, alanna |

Derived below the table:

```nix
sshServer = host.sshServer or false || host.buildServer or false;
```

**Why:** a build server is *by definition* sshed into (nix distributes builds
over ssh), so `buildServer` implies `sshServer`. Host authors set one flag and
never have to remember the implication; the derived value is what the ssh
module and the host constructor consume.

## The fixed module list

```nix
featureModules = with self.nixosModules; [ sops dev connectivity nixbuilder base
  ssh samba-timelock healthcheck power samba hardware backups nixos-management
  gaming streaming timelock shells ];
```

**Why a fixed list instead of per-host lists:** these 17 modules are *all*
inert until their `enable` option is set. Importing everything everywhere means
a host config can never forget a feature module — forgetting is impossible, and
"which features are on" is expressed once, in `enable` lines inside each host's
`_configuration.nix`. The list order matters only for module merge precedence.

`samba-timelock` is in the list too: the samba module's timelock gate is
activated by `samba.timelock.enable`, so the module must be present on every
host even though most hosts never set it.

## `mkHost`

```nix
mkHost = { hostname, system, modules, extraArgs ? {}, rpi ? false,
           nixosSystem ? inputs.nixpkgs.lib.nixosSystem }:
  assert lib.assertMsg ((hosts.${hostname}.rpi or false) == rpi)
    "${hostname}: `rpi` in rawHosts must match whether it is built with mkRpiHost";
  ...
```

Four deliberate moves, each with a reason:

1. **The assert (verbatim comment: "The table and the constructor must agree,
   in both directions").** A host built with `mkRpiHost` must be flagged `rpi =
   true` in the table, and a table entry flagged `rpi` must be built with
   `mkRpiHost`. Without it, a Pi could be built with the wrong `nixosSystem`
   (or a table entry would silently lie to `rpiHosts`, which the cache/wireguard
   docs and `regen_keys.sh` consume). Flakes evaluate at eval time, so the
   mistake fails the moment you run *any* nix command — cheap insurance.
2. **`specialArgs` injects `inputs self system selfPkgs`** (plus `extraArgs`).
   Every module file under `hosts/` can therefore write `self.lib.*` and
   `selfPkgs.foo` without importing anything. `selfPkgs =
   self.packages.${system}` is pre-applied so host files write `selfPkgs.rpcs3`
   instead of repeating the system lookup.
3. **A trailing module sets `ssh.server.enable` and
   `nixbuilder.buildServer` via `lib.mkDefault`** from the table. The table is
   the single source of truth for "am I a server?"; hosts never repeat those
   lines. `mkDefault` (not `mkForce`) so a host *can* still override if it ever
   needs to.
4. **`modules` (the host's own files) come after `featureModules`**, so
   host-specific settings win over fleet defaults in module-merge precedence.

## `mkRpiHost`

```nix
mkRpiHost = { system ? "aarch64-linux", ... } @ args:
  assert lib.assertMsg (system == "aarch64-linux")
    "mkRpiHost: Pi hosts must be aarch64-linux, got ${system}";
  mkHost (args // { inherit system; rpi = true;
    nixosSystem = args.nixosSystem or inputs.nixos-raspberrypi.lib.nixosSystem;
    extraArgs = { inherit (inputs) nixos-raspberrypi; } // (args.extraArgs or {}); });
```

- **Assert:** a Pi image built for the wrong architecture is a silent, expensive
  mistake (it just won't boot); asserting catches a typo at eval time.
- **Swaps `nixosSystem`:** `nixos-raspberrypi.lib.nixosSystem` injects the
  upstream `nixos-raspberrypi` flake's board modules and image plumbing that
  plain `nixosSystem` doesn't have.
- **Injects the `nixos-raspberrypi` input into `specialArgs`:** the Pi's
  `default.nix` can `inherit (inputs) nixos-raspberrypi` when composing board
  modules, without naming the input itself.

## How a host dir uses it

`modules/hosts/<name>/default.nix` is the thin wrapper — e.g. aria:

```nix
self.lib.mkHost {
  hostname = "aria";
  system = "x86_64-linux";
  modules = [ ./_configuration.nix ./_hardware-configuration.nix ./_hyprland.nix ];
}
```

and eris/alanna call `mkRpiHost` with `extraArgs = { inherit (inputs)
nixos-raspberrypi; }`. The table entry and the constructor call must agree —
that's what the assert enforces.
