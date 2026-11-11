# Backups

Aggregator: `modules/features/backups/default.nix` imports four
submodules (in file order): `bitwarden-backup`, `git-sync`,
`rsync-backup`, `restic-backup`. Every host inherits them through
`mkHost`'s fixed feature-module list; each is inert until its option is
enabled.

The fleet keeps data on the machines themselves — code repos, Bitwarden
vaults, home directories — and pushes it out to external targets (Google
Drive, remote servers, restic repos) over the network. That shared shape is
why the four modules look alike: each wraps a plain command-line tool
(`rclone`, `git`, `rsync`, `restic`) in a systemd unit with an ntfy
notification, and each is deliberately careful about *when* it runs —
several run at shutdown, where a hung network command would block power-off.

- [Bitwarden](backups/bitwarden.md) — stop the container, zip its data,
  upload to Google Drive, keep the newest N.
- [git-sync](backups/git-sync.md) — commit + push every git repo under
  chosen folders at shutdown.
- [rsync](backups/rsync.md) — mirror chosen folders to a local or remote
  destination, daily and/or at shutdown.
- [restic](backups/restic.md) — deduplicated, encrypted backups with
  retention pruning, daily and/or at shutdown.
