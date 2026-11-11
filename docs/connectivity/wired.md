# Wired networking — `connectivity-wired`

`modules/features/connectivity/wired.nix`. Managed ethernet via
systemd-networkd.

## Namespace gotcha

The module attr is `connectivity-wired`, but the **option namespace is
`connectivity.managed`**, not `connectivity.wired`. Host configs write
`connectivity.managed.enable = true;` — the module name and the option name
disagree, which is easy to misread.

## Options

- `connectivity.managed.enable` — managed wired networking via networkd.
- `connectivity.managed.interface` (default `""`) — the NIC to match.
- `connectivity.managed.dhcp` (default `true`) — DHCP or static IP.
- `connectivity.managed.address` / `gateway` — used only in the static case.

## Assertions — the config must be complete

- `interface` must be set (non-empty) whenever the module is enabled.
- When `dhcp = false`, both `address` and `gateway` are required:
  "Static IP requires connectivity.managed.address" / "…gateway".

These fire at eval time, so a host that picks the static variant without
giving an address fails the build rather than silently booting a machine with
no wired route.

## What it sets

- `networking.useNetworkd = true`, `enableIPv6 = true`,
  `services.resolved.enable = true` — networkd owns networking here, IPv6 is
  left on, and `resolved` provides stub resolution.
- The network entry is built with `optionalAttrs`, so exactly one of the two
  variants exists:
  - **DHCP variant** (`10-dhcp-wired`): `matchConfig.Name = interface`,
    `DHCP = "yes"`, and inside `dhcpV4Config`:
    - `ClientIdentifier = "mac"` — every fleet host shares one router, so a
      random DHCP identifier per boot would mint duplicate pseudo-entries on
      the router. Keying the client identifier to the MAC makes each host a
      stable single client.
    - `CriticalConnection = true` — fail fast at boot if the wired link can't
      be established, rather than booting half-connected.
    - `UseDomains = true` — accept the router's advertised domains for
      resolution.
  - **Static variant** (`10-static-wired`): `DHCP = "no"`, `address = [address]`,
    `gateway = [gateway]`, and `dns = [gateway]` — the gateway doubles as the
    DNS hop, so a static host still resolves names through it.

`interface` is per-host (the real NIC name differs by machine); the
collision-avoidance and fail-fast knobs are fleet-wide policy and live here
once.
