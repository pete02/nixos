# Dev tools — `dev-tools`

`modules/features/dev/tools.nix`. Nix authoring tooling, the editor, and the
container runtime.

## Options

- `dev.tools` — master switch for the whole module.
- `dev.vscode` — install VS Code and use it as the SOPS editor (default off).
- `dev.podman.enable` — use Podman instead of Docker.
- `dev.ld` — enable `nix-ld`.

## What it sets, and why

Core tooling (when `dev.tools`):
- `environment.systemPackages`: `nixd`, `nixfmt-tree`, `nvd`, `vulnix`, `jq`,
  `zip` — the Nix authoring + diffing + advisory toolchain.
- `programs.direnv` + `nix-direnv` — on-demand env loading, sped up by the
  nix-direnv cache.
- `nix.nixPath = ["nixpkgs=${inputs.nixpkgs}"]` — **pins nixpkgs to the flake
  input**, so `<nixpkgs>`-style lookups resolve to the *same* nixpkgs version
  the flake was evaluated with. Without this, legacy `<nixpkgs>` could point at
  a different (newer) channel than the flake, causing version skew.
- `nix.settings.trusted-users = ["root" config.username]` — the user may run
  GC / store-optimisation operations.

Editor (`dev.vscode`):
- installs `vscode` and sets `SOPS_EDITOR = "code --wait"`. The `--wait` flag
  is essential: `sops` blocks on the editor returning, so VS Code must
  hand control back only when the file is saved — otherwise edits are lost.

Containers — two mutually-exclusive runtimes:
- Docker (default, when `!podman.enable`): `enableOnBoot = true`, `cdi = true`
  (device support), and a **daemon mirror** `registry-mirrors = ["http://aria.local:5001"]`
  with `insecure-registries` for the same host. `aria.local:5001` is the
  fleet's Docker registry mirror (`registry` in `lib/fleet.nix`), served over
  plain HTTP on the LAN — hence "insecure". The user is added to the `docker`
  group.
- Podman (when `podman.enable`): `dockerCompat = true` (Docker-style CLI) and
  `defaultNetwork.settings.dns_enabled = true` so containers can resolve each
  other by name — the podman equivalent of Docker's default behavior.
  `podman-compose` supplies the compose CLI. Choosing Podman deliberately
  drops the privileged `docker` daemon.

`nix-ld` (`dev.ld`):
- provides the standard shared libraries (`stdenv.cc.cc`, `zlib`, `glibc`,
  `libgcc`, `libffi`, `openssl`) so dynamically-linked binaries from outside
  Nixpkgs (prebuilt toolchains, proprietary SDKs) find their `ld.so` deps — the
  usual reason to run non-Nix-built programs on a NixOS host.

## Why the design

The Docker/Podman split is a genuine either/or: the module picks Docker unless
`podman.enable` is set, because Docker is the more common default but Podman
is preferred where the rootless daemon matters. The registry mirror is wired
to `aria` specifically because that build server also mirrors the Docker Hub —
keeping container pulls on-LAN and offline-capable, exactly like the Attic
cache for Nix.
