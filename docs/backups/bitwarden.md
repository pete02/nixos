# Bitwarden — `backups-bitwarden`

`modules/features/backups/bitwarden-backup/default.nix` plus
`bitwarden-backup.sh`. Stops the Bitwarden container, zips its data folder,
uploads to Google Drive, keeps only the newest N backups.

## Options

- `backups.bitwarden.enable` — *"Bitwarden backup to Google Drive."*
- `backups.bitwarden.dataDir` — e.g. `/var/lib/bitwarden`, the folder to zip.
- `backups.bitwarden.containerName` — default `bitwarden`; the container to
  stop/start, used when `systemdUnit` is null.
- `backups.bitwarden.systemdUnit` — e.g. `docker-bitwarden.service`; *"#
  Set this if the container is managed by systemd (e.g. virtualisation.oci-containers).
  Stopping through systemd stops the unit from restarting the container
  mid-backup."*
- `backups.bitwarden.remote` — default `gdrive:bitwarden-backups`,
  `remote:folder`; the part before the colon names the rclone remote.
- `backups.bitwarden.rcloneConfigFile` — a `path` option: *"Path to the
  SOPS-managed rclone configuration file. The decrypted file must remain
  outside the Nix store."*
- `backups.bitwarden.keep` — positive int, default 5; *"Number of most
  recent backups to keep."*
- `backups.bitwarden.ntfyUrl` — default `fleet.ntfyFailure` for the
  hostname; `schedule` default `03:00`.

## What it sets, and why

- The runner is `self.lib.mkScript` with runtimeInputs `docker zip rclone
  curl gnugrep coreutils gnused inetutils` (`inetutils` for `hostname`).
- `RCLONE_CONFIG = "/run/bitwarden-backup/rclone.conf"`, and `preStart`
  copies the read-only sops file there once: *"# Initialize the writable
  configuration only when it does not exist."* — guarded by `[ ! -e ... ]`
  and installed `0600`. The reason: rclone rewrites its config, so the
  decrypted sops file (which must stay outside the store) is copied to a
  writable runtime location rather than used directly.
- `RuntimeDirectory = "bitwarden-backup"`, mode `0700`, and
  `RuntimeDirectoryPreserve = "yes"` — preserves that conf across runs so
  rclone doesn't need re-authorization each time.
- `startAt = schedule` — this unit uses the old inline timer (`startAt`),
  not a separate `systemd.timers`, unlike restic/rsync.

In the script:

- Sequence is stop → zip → **restart → upload** → prune. The restart happens
  *before* the upload with the comment *"The data is safely copied, so
  restart the service before uploading."* — minimizing downtime, since the
  upload can be slow. The container is stopped during the zip so the
  snapshot is consistent.
- Traps are installed *before* preflight — *"so runtime failures are
  reported"*. The `ERR` trap preserves the first failure as the primary
  cause (`FAILURE_CONTEXT`); the `EXIT` cleanup restarts Bitwarden if it was
  stopped (notifying "Bitwarden restart FAILED" if that fails), removes the
  temp work dir, and sends exactly **one** "Bitwarden backup FAILED"
  notification (a `NOTIFICATION_SENT` flag prevents double-reporting), with
  a journalctl hint.
- `check_dependencies` requires `systemctl` when `SYSTEMD_UNIT` is set, else
  `docker` — matching the `systemdUnit`/`containerName` split.
- rclone credentials: when `RCLONE_CONFIG` is set rclone uses that file
  directly; otherwise `RCLONE_TOKEN_FILE` configures the remote via
  `RCLONE_CONFIG_<NAME>_*` env vars. `setup_rclone_remote` sets
  `TYPE=drive` and `SCOPE=drive.file` — the minimal scope, since only file
  access is needed.
- Pruning lists first, then deletes: *"# Store the listing before pruning.
  This ensures listing failures are not accidentally hidden by a pipeline or
  an empty grep result."* — `rclone lsf --files-only` is captured, filtered
  with `grep -E '^bitwarden-backup-.*\.zip$' | sort`, and the oldest beyond
  `KEEP` removed via `rclone deletefile`.
- `notify()` is best-effort: `curl` with `Title`/`Priority: high` headers,
  returning 0 on failure — *"Notifications are best-effort; curl is not
  required for the backup itself."*

## Why the design

Bitwarden's data lives inside a running container, so a zip of it while
live would be inconsistent — hence the stop-then-zip ordering, and the
restart-before-upload ordering to keep the vault service back online
quickly. The rclone config is a SOPS-managed file that must stay outside the
Nix store, which is why it's copied to a private `/run` location (writable,
preserved across runs) rather than decrypted into the store. `drive.file`
scope and the `KEEP` pruning keep the Google Drive backup small, and the
single-notification design avoids a flood of duplicate failure pings.
