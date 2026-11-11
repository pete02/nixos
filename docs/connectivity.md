# Connectivity

Aggregator: `modules/features/connectivity/default.nix` imports five
submodules (in file order): `connectivity-bluetooth`, `connectivity-wifi`,
`connectivity-mDNS`, `connectivity-wired`, `connectivity-wireguard`. Every
host gets them through `mkHost`'s fixed feature-module list; each is inert
until its option is enabled.

The fleet shares one router and one LAN, so these modules are written to
coexist across all five machines rather than per-host:

- [Wired](wired.md) — networkd-managed ethernet (DHCP or static), the
  collision-avoidance knobs for several hosts on one router.
- [WireGuard](wireguard.md) — out-of-band `wg0` over a separate 10.0.0.x
  range, per-site keypairs from sops.
- [WiFi](wifi.md) — NetworkManager + `wpa_supplicant`, PSK from sops.
- [mDNS](mdns.md) — Avahi, so `hostname.local` resolves fleet-wide.
- [Bluetooth](bluetooth.md) — experimental directives + gamepad driver.
