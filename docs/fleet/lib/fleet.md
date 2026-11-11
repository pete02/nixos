# Fleet constants (`lib/fleet.nix`)

Leaf doc. `self.lib.fleet` is one recursive attrset of every constant more than
one module needs. Each value below explains *why* it is shaped like it is.

## Identity & naming

```nix
domain = "local";
fqdn = host: "${host}.${domain}";
installerHosts = [ "x86" "rpi3" "rpi5" ];
```

- **`domain = "local"`** — the fleet resolves machines as `aria.local`,
  `raysha.local`… over mDNS (see the connectivity module). `.local` is the
  conventional hostname suffix Avahi answers for, so no DNS records are needed
  anywhere.
- **`installerHosts`** lists the flake attrs the installer can target; the
  install tool and the ISO both read this so they can never drift from the
  images that actually exist.

## LAN geometry

```nix
lan.subnet = "192.168.88.0/24";
wireguard.hosts = { eris = "10.0.0.3"; };
```

- **`lan.subnet`** is the router's network; the wired module asserts every
  static-IP host sits inside it, and the containerised-desktops module checks
  macvlan IPs against it. One definition, checked in two places.
- **`wireguard.hosts`** allocates each wireguard site its address out-of-band
  (`10.0.0.x`) so a wireguard `wg0` can never collide with a LAN static
  allocation. Only eris has a site today; the map shape is there so adding a
  second host is one line. Hosts missing from the map get `throw`ed at eval
  time — a site with no address is a silent misconfiguration otherwise.

## ntfy topics

```nix
ntfy.base = "https://ntfy.lumilukko.com";
ntfyFailure = host: "${ntfy.base}/failure-${capitalise host}";
ntfyUpgrade = ... ; ntfyBackup = ...;
```

- **One server, three topic families** (`failure-*`, `upgrade-*`, `backup-*`):
  a subscriber can mute whole categories and per-host topics are visible in the
  server's topic list. `capitalise` is a 1-line helper so the topic style stays
  uniform (`raysha` → `failure-Raysha`) — ntfy topic names are case-sensitive,
  so a host that forgot to capitalise would post to an orphan topic nobody
  subscribed to.
- **Functions of `host`, not a table:** every consumer already knows which host
  it runs on (`config.hostname`), so a lookup table would be indirection.

## Signing & cache

```nix
signingKeys = { raysha = "raysha-1:W73o..."; };   # public key — fine to name
cache = { host = "aria"; addr = "192.168.88.241"; # keep the IP; see caveats
  port = 8080; name = "main"; publicKey = "main:+9aO...";
  envSecret = "services/attic/env"; pullTokenSecret = "services/attic/pull_token";
  apiEndpoint = ...; url = ...; };
```

- **`signingKeys` holds only public keys** (the comment marks them as public
  identifiers). The matching *private* signing key is a sops secret
  (`nix/signing/<host>`); fleet policy is "every host trusts every fleet key",
  so the public half must be visible in the store-wide `public-keys` config —
  that's why it lives here and not in sops.
- **Only raysha signs.** Adding a signer is one line here plus one sops secret;
  the nixbuilder module derives `enable = hostname ∈ signingKeys` from this map.
- **`addr` is an IP, verbatim comment "# keep the IP; see caveats":** the cache
  server is fetched by *other* machines' nix (during remote builds), where mDNS
  `.local` resolution isn't guaranteed in the build hook's environment — an IP
  always resolves.
- **`publicKey`** is the cache's signing identity (public by definition); the
  pull token and server env live in the two named sops secrets so nothing
  secret appears in the store.
- **`apiEndpoint`/`url` derive from `addr`/`port`/`name`** so the client hook,
  the server config, and the docs can never disagree about the address.

## Samba shares

```nix
# host + share + mount + secret, defined once
samba.shares = {
  server   = { host = "192.168.88.241"; mountPoint = "/mnt/server";   credentialsSecret = "samba/server"; };
  timelock = { host = "192.168.88.241"; mountPoint = "/mnt/timelock"; credentialsSecret = "samba/timelock"; };
  rpi      = { host = "192.168.88.86";  mountPoint = "/mnt/rpi";      credentialsSecret = "samba/rpi"; };
};
```

- **The comment is the whole reason:** the same triple (server IP, mount point,
  credentials secret) is needed by the *server* side (smbd share config) and the
  *client* side (CIFS mount + credentials). Defining it once here means a
  client's `samba.clients.server.enable = true` pulls the correct IP, mount and
  secret automatically — and the client module `throw`s a helpful message
  naming this table when a share is requested that isn't in it.
- **Separate secret per share** (`samba/server`, `samba/timelock`, `samba/rpi`):
  the timelock share's SMB users are gated separately from the general server
  share, so they rotate independently.

## Non-NixOS devices

```nix
# Machines that aren't (or aren't only) NixOS hosts
devices = {
  raysha.mac = "88:d8:...";
  alanna = { mac = "2C:CF:..."; sshKeyFrom = "raysha"; };
};
```

- **Macs keyed by MAC address:** the AdGuard/timelock gate and the wired
  module's `ClientIdentifier` need the stable per-device MAC. These are
  identifiers, not secrets.
- **`sshKeyFrom = "raysha"`:** alanna (a Pi) borrows raysha's SSH identity
  because it isn't always a NixOS host — the ssh module reads this to reuse
  raysha's keypair instead of inventing alanna's own.

## Registry

```nix
registry = { host = "aria"; port = 5001; }; # docker mirror in dev/tools.nix
```

The dev-tools module builds the podman/docker registry config from this one
entry; the comment tells the reader where it is consumed.
