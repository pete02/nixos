# Base system

Aggregator: `modules/features/base/default.nix` imports `base-apps` and
`base-settings`. Every host gets this module — `mkHost`'s fixed feature-module
list includes `base`, so there is no host-side `enable` for it.

Two layers, very different in kind:

- [Settings](base/settings.md) — the always-on core: identity (`username`,
  `hostname`), groups, Finnish locale, Nix defaults. Everything else in the
  flake derives from the options it declares.
- [Apps](base/apps.md) — opt-in `common-tools.{modeling,books,school}` bundles
  for the human uses of the machines.
