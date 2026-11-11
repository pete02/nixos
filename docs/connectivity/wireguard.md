# WireGuard — `connectivity-wireguard`

`modules/features/connectivity/wireguard.nix`. An out-of-band `wg0` link to
non-LAN endpoints (the eris Pi talking to a remote WireGuard server), kept in a
separate address space from the LAN so it never collides with the other hosts.

## Options

`connectivity.wireguard` is an `attrsOf submodule` — one entry per site, each
with:

- `endpoint` (str) — the remote endpoint.
- `allowed_ips` (listOf str) — source IPs permitted on that peer.
- `address` — the local `wg0` address; default pulls from
  `self.lib.fleet.wireguard.hosts.${config.hostname}`, and if the hostname
  isn't in that table it `throw`s:
  "connectivity.wireguard: no address for … in fleet.wireguard.hosts; set
  \`address\` explicitly".

The default lives in the [fleet library](../fleet/lib/fleet.md): eris is
allocated `10.0.0.3`, deliberately outside the LAN's
`192.168.88.0/24` so `wg0` can't collide with any host's normal network. A
host not listed there must state its own address — the throw makes a missing
allocation a build error, not a silent wrong-IP boot.

## How it works

Gated on `cfg != {}` — the module does nothing until at least one site is
declared.

- **Secrets, per site**: `sops.secrets` is folded over the site names,
  creating a `private_key` (mode `0400`) and `public_key` (mode `0440`) entry
  each, owned by group `systemd-network` — networkd reads the keypair, so the
  decrypted files must be readable by it, not world-readable. Secret paths are
  `services/wireguard/<site>/private_key` (see [secrets](../secrets.md)).
- **networkd object**: `networking.useNetworkd = true`,
  `systemd.network.enable`, and a `netdevs."50-wg0"` with
  `Kind = "wireguard"`, `Name = "wg0"`. networkd itself does the
  key-agreement/noise setup — no userspace daemon.
  - `wireguardConfig`: `ListenPort = 51820` (the single local keypair's
    listening port), `PrivateKeyFile` = the **first** site's private key,
    `RouteTable = "main"`, `FirewallMark = 42`.
  - `wireguardPeers`: one entry per site — `PublicKeyFile`, `AllowedIPs`,
    `Endpoint`, `PersistentKeepalive = 25`.
- Only the first site's private key is used: networkd carries one local
  keypair per `wg0`; the other sites are reached with their public key +
  endpoint as additional peers on the same local key.
- `networking.firewall.allowedUDPPorts = [51820]` — WireGuard is UDP, so the
  listen port must be opened.
- `networking.networkmanager.unmanaged = ["wg0"]` — NetworkManager must not
  try to own `wg0`; networkd does, so the interface is marked unmanaged for NM.
- `wireguard-tools` added to systemPackages for manual inspection.

## Why the design

The whole point is coexistence: `wg0` lives in `10.0.0.x`, the LAN in
`192.168.88.x`, so a host can be on the LAN and on the out-of-band link at
once. The `25`-second keepalive keeps a rarely-used remote link from timing
out its key agreement. Ownership by `systemd-network` (not root) is what lets
the unprivileged networkd service read the sops-decrypted keypair.
