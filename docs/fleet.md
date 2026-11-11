# The shared library (`modules/lib/`)

Three flake parts that declare options on `flake.lib`, which everything else
reaches as `self.lib.*`. They exist so host configs never hardcode IPs, names,
or shared policy again.

| File | Declares | Purpose |
|---|---|---|
| `lib/default.nix` | `flake.lib` (empty default) | the one place the `lib` namespace is defined |
| `lib/hosts.nix` | `self.lib.hosts`, `rpiHosts`, `mkHost`, `mkRpiHost` | the host table + the host constructors |
| `lib/fleet.nix` | `self.lib.fleet` | fleet-wide constants: LAN, ntfy, cache, samba, devices |
| `lib/scripts.nix` | `self.lib.mkScript` | build-time-checked shell script wrapper |

Details:

- [Host table and constructors](lib/hosts.md) — why `mkHost` asserts, why every
  host gets the same 17 modules
- [Fleet constants](lib/fleet.md) — why the IPs, ntfy topics, signing keys and
  share table are shaped like they are
- [Script builder](lib/scripts.md) — why every repo script carries a `--check`
