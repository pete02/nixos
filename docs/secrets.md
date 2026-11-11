# Secrets (sops-nix)

Two pieces: the **sops feature module** (`modules/features/sops/`) that wires
sops-nix into every host, and the **encrypted file** (`secrets/secrets.yaml`)
that holds the actual values. This doc is a leaf — secrets are a single
subsystem — but it explains both how the glue works and why it is set up the
way it is. **Secret values are never documented here; names and paths are.**

## The module (`modules/features/sops/default.nix`)

```nix
sops.defaultSopsFile = "${self}/secrets/secrets.yaml";
sops.format = "yaml";
sops.age.keyFile = "/etc/sops/age/keys.txt";
```

- **`defaultSopsFile` points at `${self}/secrets/secrets.yaml`** — the
  flake's *own source tree* (the repo directory, since `self` is this flake).
  The encrypted file travels with the flake, so any host that has the repo
  checked out can decrypt with the right key. No separate secret repo, no
  out-of-band file.
- **`age` backend, key file at `/etc/sops/age/keys.txt`** — a fixed
  machine-level path, installed by [tools/bootstrap.sh](tools.md) at
  bootstrap time. sops-nix reads that file at runtime to decrypt; sops-nix
  itself never needs to know the key contents.
- **`pkgs.sops` is added** so the raw `sops` CLI works on the host (for
  `tools/regen_keys.sh`-style editing).

### The one pre-declared secret

```nix
rclone-gdrive-config = { src = ./../../../secrets/rclone-gdrive.conf.ini; format = "ini"; key = ""; };
```

rclone's Google Drive config (the `refresh_token` inside) is an opaque INI
file, not a YAML value — so it is its *own* sops-encrypted file with
`format = "ini"` and an empty key (the whole file is the secret). The module
pre-declares it once so every consumer just references
`config.sops.secrets.rclone-gdrive-config.path`; bitwarden-backup feeds that
path to `rclone`'s `-config`. Decrypting it at runtime keeps the token out of
the Nix store — the path lives under `/run/...` (or `/etc/...`), never a
store path.

## The keys in `secrets.yaml` (names only)

| Key | Consumed by |
| --- | --- |
| `samba.server`, `samba.timelock`, `samba.rpi` | samba shares — smbpasswd per server; client mount credentials ([fleet table](fleet/lib/fleet.md) names the matching share) |
| `ssh.hosts.<host>.private_key` / `public_key` | ssh client IdentityFile + authorized-keys union ([ssh module](ssh.md)) |
| `ssh.hosts.<host>.host_key.private` / `public` | host keys — `hostKeys = []` in the ssh module stops NixOS auto-generating; sops supplies these ([ssh module](ssh.md)) |
| `restic.aria`, `restic.raysha` | restic `passwordSecret` per host ([backups](backups.md)) |
| `wifi.psk` | wifi — pre-computed WPA PSK injected via a wifi-env template + NM `key-mgmt = "wpa-psk"` profile ([connectivity](connectivity.md)) |
| `services.wireguard` | wireguard keypairs (0400/0440, owner systemd-network) ([connectivity](connectivity.md)) |
| `services.github`, `services.forgejo` | `/etc/ssh/ssh_config` IdentityFile mappings to GitHub and the self-hosted Forgejo ([dev](dev.md)) |
| `services.attic.env` / `services.attic.pull_token` | Attic server env + pull token ([nixbuilder](nixbuilder.md)) |
| `services.github` | GitHub token ([dev](dev.md)) |
| `nix.signing.<host>` | signing *secret* key per build server; the public half lives in [fleet.signingKeys](fleet/lib/fleet.md) ([nixbuilder](nixbuilder.md)) |
| `alanna.tmdb_api_key` | Pegasus kiosk TMDB metadata ([shells](shells.md)) |
| `hello`, `agh`, `hf_token` | spare/scalar secrets (sops `--value-stdin` style entries) |

The YAML footer declares `unencrypted_suffix: _unencrypted` — keys ending in
that suffix stay in plaintext (sops creation-rule convention), and the
`key_policies` block in `.sops.yaml` pins which regexes are encrypted.

## Why the signing key pairs split across two places

The *public* signing keys live in [fleet.signingKeys](fleet/lib/fleet.md)
(public information — every host must trust them anyway, and Nix needs them in
`config.nix.publicKeys` verbatim); the *secret* half lives in sops
(`nix/signing/<host>` → `secret-key-files`). The signing keypair is therefore
never decryptable from the public half and vice versa. Same pattern for ssh:
public keys in the fleet table / authorized-keys, private keys in sops.
