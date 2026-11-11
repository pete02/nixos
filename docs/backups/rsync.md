# rsync — `backups-rsync`

`modules/features/backups/rsync/default.nix` plus
`modules/features/backups/rsync/rsync-backup.sh`. Mirrors chosen folders to
a local or remote destination, daily and/or at shutdown.

## Options

- `backups.rsync.enable`, `user` — *"For remote destinations, this user's
  SSH keys and `known_hosts` are used."*
- `backups.rsync.destination` — local (`/mnt/backup`) or remote
  (`user@host:/backups/raysha`); *"Each source path is recreated below it,
  so `/home/alice/code` ends up at `<destination>/home/alice/code."*
- `backups.rsync.folders`, `exclude`, `extraArgs`
- `backups.rsync.delete` — default `false`: *"Delete files from the
  destination that no longer exist in the source, so the destination mirrors
  the source. Off by default so that deleting something by accident does not
  also delete its backup."*
- `backups.rsync.sshKey` — *"must not have a passphrase, because there is
  no ssh-agent when the service runs."*
- `backups.rsync.schedule` — default `daily`; *"A run missed because the
  machine was off is made up at the next boot."*
- `backups.rsync.runOnShutdown` (default true), `shutdownTimeout`
  (default `5min`): *"If it takes longer, it is killed so the machine can
  still power off. The next run picks up where it left off."*
- `backups.rsync.ntfyFailure` / `ntfySuccess` — defaults from the fleet
  ntfy topics for the hostname.

## What it sets, and why

- Substitution values are all shell-escaped — *"# Every value must be a
  string and shell-escaped, as it is pasted into the script."*
- `LOCKFILE = "/run/rsync-backup/lock"` — *"Shared by the daily and the
  shutdown run, so they never overlap."* The script `flock`s on it.
- `RSYNC_RSH` is `ssh -o BatchMode=yes -o ConnectTimeout=10` — *"Never hang
  on a prompt, and give up quickly if the network is down."* When `sshKey`
  is set it appends `-i <key> -o IdentitiesOnly=yes` so only that key is
  offered.
- `localPaths` filters destination + folders to absolute paths;
  *"# Local paths involved: the backup must not run (and, on shutdown, must
  keep running before they are unmounted) unless they are mounted. This also
  stops a backup into an empty mount point on the root filesystem when a
  drive is unplugged."* That feeds `RequiresMountsFor`.
- `Nice = 10` and `IOSchedulingClass = "idle"` — *"Stay out of the way of
  whatever the machine is doing."*
- The shutdown unit uses the same stop trick: *"# The unit 'starts' at boot
  (doing nothing) and does its work when it is stopped, which systemd does
  on shutdown/reboot. Stop order is the reverse of start order, so ordering
  it after the network means the backup runs while the network is still
  up."* Note the difference from restic: here `ExecStop` runs the exe
  directly (no `is-system-running` guard), so `stopIfChanged = false` is the
  only thing keeping `nixos-rebuild switch` from backing up.
- `restartIfChanged = false; stopIfChanged = false` — *"Do not run the
  backup (i.e. stop the unit) on `nixos-rebuild switch`."*
- `Persistent = true` on the timer is why the schedule description promises
  missed runs are made up at boot.

In the script:

- Base args are `-a --relative --mkpath --partial --info=stats1`; `--delete`
  is added only when `DELETE=1`, `--exclude=` per pattern. `--relative` is
  what recreates the source path under the destination; `--mkpath` creates
  those intermediate dirs on a fresh destination; `--partial` keeps partial
  files so an interrupted run resumes.
- `--no-inc-recursive` with `PROGRESS_INTERVAL` (default 60): *"# --no-inc-recursive
  makes rsync scan the folder up front, which gives an accurate percentage
  and ETA."* A `throttle_progress()` filter logs progress once per minute
  when not on a terminal (`tr '\r' '\n'`, keep only `xfr#` lines per
  interval).
- Exit code 24 is tolerated: *"done (some files vanished while copying,
  which is normal for live data)"* — counted as success, not failure.
- `ssh` is added to `REQUIRED_CMDS` only for remote destinations (`*:*`
  patterns), `curl` only when an ntfy URL is configured — the script's
  dependency set matches what it actually needs.
- A failure in one folder does not stop the others; the summary line
  reports `Folders: N | ok: X | failed: Y`, and failure notifications list
  each failed folder.

## Why the design

rsync is the plain mirror for data restic doesn't cover (or where
deduplication is overkill). The `delete = false` default is the safety
decision: an accidental deletion shouldn't propagate into the backup. The
exit-24 tolerance, the `BatchMode`/`ConnectTimeout` ssh options, and the
`sshKey`-without-passphrase constraint all exist because the service runs
during shutdown with no terminal and possibly no network. `--relative` plus
the destination-recreation description is why the destination layout mirrors
the source paths instead of flattening them.
