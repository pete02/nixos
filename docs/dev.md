# Development — `dev`

`modules/features/dev/default.nix`. Aggregates the four development
submodules.

## Options

`dev` is a namespace; each submodule contributes its own key:

- `dev.android` — `dev-android`
- `dev.git` — `dev-git`
- `dev.virtualization` — `dev-virtualization`
- `dev.tools` / `dev.vscode` / `dev.podman.enable` / `dev.ld` — `dev-tools`

## How it works

`dev` just `imports` the four submodules under `self.nixosModules`, so a
host can turn on any subset independently. Every submodule is guarded by its
own `lib.mkIf`, so enabling one never drags in the others.

Why this grouping exists: development is the one area where hosts legitimately
differ — a build server wants the Nix toolchain, a desktop wants VS Code, a
kitchen Pi wants neither. The aggregator gives one switch (`dev`) to pull the
whole set when a host wants "everything," while the sub-keys let a host
cherry-pick.

→ Read the leaves:
- [tools](tools.md) — Nix tooling, direnv, editor, containers, `nix-ld`
- [git](git.md) — git client + GitHub/Forgejo ssh identities
- [android](android.md) — Android device access
- [virtualization](virtualization.md) — KVM / libvirt
