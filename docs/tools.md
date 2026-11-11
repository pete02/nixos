# Repo tooling (`tools/`)

Shell scripts that run *against* this repo on a host — they are not part of the
flake. Each is a leaf doc's subject; read the one you need.

| Script | What it does | Run it… |
| --- | --- | --- |
| `tools/bootstrap.sh` | Install the bootstrap credentials: age keys + Attic netrc | once, on a fresh host ([details](tools/bootstrap.md)) |
| `tools/generate_keys.sh` | Generate the ssh keypair set for one new host | when adding a host ([details](tools/keys.md)) |
| `tools/regen_keys.sh` | Regenerate ssh keypairs for every host and merge into secrets | when rotating all keys ([details](tools/keys.md)) |
| `tools/test.sh` | Interactive `nixos-rebuild switch` with logging | when testing a rebuild ([details](tools/test.md)) |

These scripts are the *only* place secrets get written; the flake itself never
writes secret material (sops files are edited, not generated, except by
generate/regen_keys).
