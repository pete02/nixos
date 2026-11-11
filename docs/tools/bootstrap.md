# `bootstrap.sh` — first-host credential bootstrap

What it installs, and why each piece must exist before anything else can run.

## Shape

Re-execs under sudo (`if [[ $EUID -ne 0 ]]; then exec sudo -- "$0" "$@"; fi`),
then asks for a **Linux username** (validated against `^[a-z_][a-z0-9_-]*[$]?$`
and existence-checked with `id`), then reads the **Attic pull token** with
`read -rsp` — the `-s` flag keeps it off screen and `-p` prompts; the token
never appears in argv or history.

## What it writes

| File | Mode | Why |
| --- | --- | --- |
| `/etc/sops/age/keys.txt` | root-owned | the **root** age key — sops-nix's `sops.age.keyFile` on every host points here ([secrets](secrets.md)) |
| `~/.config/sops/age/keys.txt` | user-owned | the **user's** age key so the plain `sops` CLI edits secrets without sudo |
| `/etc/nix/attic.netrc` | `install -o root -g root -m 600` | Attic credentials: `machine 192.168.88.241`, `login attic-token`, `password <token>` |

The netrc is written to a temp first, then `install`-ed at 0600 — the mode is
set atomically by `install`, never by chmod-after-the-fact (a 0644 window would
briefly leak a readable token file).

## Why it prints the public keys

After generating the private keys (`age-keygen`), it runs `age-keygen -y` to
print the **public** half — that's what you paste into `.sops.yaml`'s
`key_policies` (the encryption rules) and into other machines' key files. The
public key is safe to display; the private key only ever goes to the files
above.

## Why it tests the Attic token

```
curl --netrc-file "$ATTIC_NETRC" --write-out '%{http_code}' \
  http://192.168.88.241:8080/main/nix-cache-info
```

`nix-cache-info` is a harmless GET every Nix client makes; expecting `200`
proves the token is valid *against the cache that will serve this host's
builds* ([fleet cache](fleet/lib/fleet.md): aria, port 8080, `main` repo) before
the first big build starts and then fails at upload time. Non-200 → hard error
with the code, so a bad token fails at bootstrap, not at rebuild.

Closing hint reminds you: builds need `--option netrc-file /etc/nix/attic.netrc`
(or the equivalent in `nix.conf`) until the flake's own
[nixbuilder Attic client](nixbuilder.md) templates are installed by a rebuild.
