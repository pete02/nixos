# NixOS fleet

One flake, five machines, one repo. Everything lives under `modules/`, which
`flake.nix` pulls in wholesale with `import-tree ./modules` — every `.nix` file
under `modules/` is a flake part, and each declares its module attr name
explicitly (`flake.nixosModules.<name> = ...`), so file layout and attr names are
independent.

```
flake.nix            # mkFlake; imports = [ (import-tree ./modules) ]
modules/
  parts.nix          # perSystem: formatters, systems
  lib/               # shared helpers + fleet-wide data (self.lib.*)
  features/          # the feature modules every host composes
  hosts/             # one dir per machine: default.nix + _configuration.nix + ...
  installer/         # ISO / SD images + the install tool
```

## Where things live

| Area | Read | What it covers |
|---|---|---|
| Shared library | [fleet.md](fleet.md) | `lib/hosts.nix`, `lib/fleet.nix`, `lib/scripts.nix` — the data and helpers everything else consumes |
| Hosts | [hosts.md](hosts.md) | `mkHost` / `mkRpiHost`, the per-host dirs, the `_`-prefix convention |
| Secrets | [secrets.md](secrets.md) | sops-nix layout: which secret exists, where it is consumed (never values) |
| Repo tooling | [tools.md](tools.md) | `tools/` scripts: bootstrap, key generation, rebuild runner |
| Installer | [installer.md](installer.md) | ISO/SD images and `nixos-installer.sh` |
| Features | see below | the 17 feature modules every host inherits |

## Feature modules

Every host gets all of these automatically (`lib/hosts.nix` injects them); each
is inert until its `enable` option is set.

| Feature | Module dir | Options namespace |
|---|---|---|
| Base system | `features/base/` | [base.md](base.md) | `base-settings`, `base-apps` |
| Connectivity | `features/connectivity/` | [connectivity.md](connectivity.md) | wifi, wired, wireguard, mDNS, bluetooth |
| Dev environment | `features/dev/` | [dev.md](dev.md) | git, tools, android, virtualization |
| Gaming | `features/gaming/` | [gaming.md](gaming.md) | steam, performance, compatibility, graphics, rpcs3 |
| Hardware | `features/hardware/` | [hardware.md](hardware.md) | gpus, cachyos kernel, mdadm, peripherals, gpu-cooler |
| Backups | `features/backups/` | [backups.md](backups.md) | restic, rsync, git-sync, bitwarden |
| Shells / desktops | `features/shells/` | [shells.md](shells.md) | hyprland, wayle, bigscreen, cage kiosk, displaymanager, services |
| SSH | `features/ssh/` | [ssh.md](ssh.md) | host/client identity, key management |
| Samba | `features/samba/` | [samba.md](samba.md) | LAN shares + the timelock gate |
| Time-lock | `features/timelock/` | [timelock.md](timelock.md) | the usage-session state machine |
| Nix building | `features/nixbuilder/` | [nixbuilder.md](nixbuilder.md) | distributed builds + Attic cache |
| System management | `features/nixos-management/` | [nixos-management.md](nixos-management.md) | auto-update + gitops deploy |
| Health checks | `features/healthcheck/` | [healthcheck.md](healthcheck.md) | SMART / mdadm / bcachefs spot checks |
| Power | `features/power/` | [power.md](power.md) | TLP + thermald |
| Secrets (sops) | `features/sops/` | [secrets.md](secrets.md) | the sops-nix glue |
| Streaming | `features/streaming/` | [streaming.md](streaming.md) | Sunshine: host-side + containerised desktops |

Index docs here just point down the chain; the leaf docs at the end of each
chain carry the depth — how the subsystem works and *why* each setting is set
the way it is.
