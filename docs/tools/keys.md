# ssh key tooling (`generate_keys.sh`, `regen_keys.sh`)

Leaf doc. ssh keys are *the* fleet-wide secret subsystem: every host gets a
client identity, and every ssh-*server* host gets a host key. These two scripts
are how that material is created and rotated. Values are never printed here.

## What the ssh subsystem expects (`ssh.hosts.<host>.*` in secrets)

The [ssh module](ssh.md) consumes, per host, four entries:
`private_key`, `public_key` (the client identity), and `host_key.private`,
`host_key.public` (the host's presented key). `generate_keys.sh <hostname>`
creates exactly those four for one host; `regen_keys.sh` recreates them for
every host in the repo.

## `generate_keys.sh <hostname>`

```
ssh-keygen -t ed25519 -N '' -C "$host"        # client identity
ssh-keygen -t ed25519 -N '' -C "$host-host"   # host key
```

- **ed25519** everywhere — modern, small, no passphrase (`-N ''`); the fleet
  is passwordless by design ([fleet](fleet/lib/fleet.md) `sshKeyFrom`,
  authorized-keys union).
- **`-C "$host"` / `-C "$host-host"`** put the hostname in the comment field so
  a key on the wire is self-identifying.
- `set_secret()` stores each file with `jq -Rs . | sops set --value-stdin` into
  the nested path `["ssh"]["hosts"]["<host>"]["<field>"]` — `--value-stdin`
  keeps the key material off argv (process listing), `jq -Rs` turns the file
  into one JSON string so the multi-line PEM survives as a single YAML scalar.

## `regen_keys.sh` — the interesting one

Regenerates the whole set and merges it into `secrets/secrets.yaml`. Its own
comments carry the hard-won reasoning; verbatim:

- **Host discovery is two-layered.** Subdirectories of `modules/hosts/` list
  candidate hosts; then it asks the *flake* for the real ssh-server set:
  `nix eval --json '.#lib.hosts' --apply '... builtins.filter (h:
  hosts.${h}.sshServer or false) ...'` — comment: *"so this never drifts out of
  sync with the real source of truth"*. The table in
  [hosts.nix](fleet/lib/hosts.md) decides who is a server; the script trusts
  the eval, not the directory names. A fallback comment notes a stale
  `host_key` is harmless (*"an unused host_key in secrets.yaml just sits there
  unreferenced"*).
- **Identity keypairs for all hosts; host_key keypairs only for servers** —
  matches the [host table](fleet/lib/hosts.md) derivation (`sshServer =
  buildServer or rpi or …`).
- **Deep-merge over the decrypted YAML** (python3 + pyyaml): new
  `ssh.hosts.*` values overwrite old, everything else stays — regenerating
  keys must not clobber the *other* secrets ([secrets](secrets.md) keys).
- **Private key material rendered as literal block scalars (`|`)** to match the
  existing `secrets.yaml` style, so the file stays diff-friendly.
- **`sops --filename-override "$SECRETS_FILE" -e`** with the verbatim comment:
  *"--filename-override tells sops to match .sops.yaml creation rules as if the
  input were at $SECRETS_FILE, even though it physically lives in $WORKDIR
  right now. Without this, sops matches against the tmp path and fails with
  'no matching creation rules found'."* — the re-encryption happens in a temp
  file, but the creation rules must apply as if it were the real path.
- **Sanity check `grep -q '^sops:'` before an atomic `mv`** (same filesystem),
  with the comment *"never truncate-then-hope"* — the encrypted block must be
  present before the temp replaces the real file; `mv` on one filesystem is a
  rename, so the real file is never half-written.
- **`trap … shred -u`** on exit: the decrypted temp (which holds *every* secret,
  not just ssh) is shredded, not merely deleted — deleted-but-open files stay
  readable until the fd closes, shred zeroes the blocks.
- Closing note, verbatim in spirit: *"rebuild servers (aria, raysha) before
  clients — servers need their new host_key live (and to trust clients' new
  public_key) before clients rebuild their known_hosts / start using their new
  private_key against them."* Key rotation has an ordering dependency across
  the fleet; the [ssh module](ssh.md) known_hosts + authorized-keys union is
  what makes the new keys visible to the other side.

The known_hosts line in the [dev/git module](dev.md) (`git.lumilukko.com:2222`)
carries a matching comment — *"from: ssh-keyscan -p 2222 -t ed25519
git.lumilukko.com"* — pinning how that entry was captured.
