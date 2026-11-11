# mDNS — `connectivity-mDNS`

`modules/features/connectivity/mdns.nix`. Makes `hostname.local` resolve
fleet-wide, which is what every other module's `.local` addressing depends on.

## Naming bug to know about

The module attr is `connectivity-mDNS` and the option is
`connectivity.mDNS`, but the `mkEnableOption` description string is literally
`"bluetooth"` — a copy-paste leftover. It's cosmetic; the option name is
correct.

## What it sets, and why

- `services.avahi.enable = true` — Avahi is the mDNS discovery daemon; the
  fleet relies on `.local` names (see [fleet library](../fleet/lib/fleet.md):
  `domain = "local"`, `fqdn host = "${host}.local"`).
- `nssmdns4 = true` — installs the mDNS NSS hook so plain glibc name
  resolution (`gethostbyname`) answers `*.local`, not just Avahi-aware
  programs. Without it, ssh/ping/curl wouldn't see the names.
- `publish.addresses = true` — Avahi normally publishes only names; the fleet
  also wants the resolved **addresses** advertised, so other hosts can look up
  a machine's LAN IP by name.
- `allowInterfaces = lib.mkIf (config.connectivity.wireguard != {}) (lib.attrNames config.connectivity.wireguard)`
  — Avahi filters out "non-normal" interfaces when publishing. The `wg0`
  interface from [WireGuard](wireguard.md) is exactly such a non-normal one,
  so its name (from `connectivity.wireguard`'s site attrs) must be explicitly
  allowed for it to be advertised. Gated so it only applies when wireguard is
  actually in use.

## Why it matters

The whole fleet is addressed by `aria.local`, `raysha.local`, etc. — mDNS is
the glue that turns those names into working resolution on every machine
without an `/etc/hosts` file. The `nssmdns4` hook is the specific reason
non-Avahi tools work; the `publish.addresses` + `allowInterfaces` pair is the
specific reason the out-of-band `wg0` link is discoverable too.
