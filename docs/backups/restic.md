# restic — `backups-restic`

`modules/features/backups/restic/default.nix` plus
`modules/features/backups/restic/restic-backup.sh`. Deduplicated,
encrypted backups to a local or sftp: repository, with retention pruning.

## Options

- `backups.restic.enable`, `user`
- `backups.restic.repository` — local path or `sftp: remote`.
- `backups.restic.passwordSecret` — default `restic/${config.hostname}`; the
  module declares the sops secret and grants the user read access to it.
- `backups.restic.folders`, `exclude`, `extraArgs`
- `backups.restic.pruneOpts` — default
  `["--keep-daily 7" "--keep-weekly 5" "--keep-monthly 12"]`.
- `backups.restic.schedule` — default `daily`; *"Missed runs are made up
  when the machine starts."* (`Persistent = true` on the timer.)
- `backups.restic.runOnShutdown` (default true), `shutdownTimeout`
  (default `5min`).
- `backups.restic.ntfyFailure` / `ntfySuccess` — default from
  `self.lib.fleet.ntfyFailure` / `ntfyBackup` for the hostname.

## What it sets, and why

- Values are passed into the script as substitutions because *"Values are
  shell-escaped because they are inserted into the script."*
- `LOCKFILE = "/run/restic-backup/lock"` is *"Shared by the scheduled and
  shutdown services"* — the script `flock`s on it, so a daily run and a
  shutdown run never overlap.
- `RequiresMountsFor = localPaths` where `localPaths` filters the
  repository and folders to absolute paths — the backup must not run unless
  its sources are mounted.
- `OnFailure = ["restic-backup-failure.service"]` — *"Fires for any failure,
  including mount failures and kills."* That failure unit is `DynamicUser`
  and curls an ntfy message (`--retry 5 --retry-delay 5 --retry-all-errors`),
  so a broken backup still announces itself.
- `restartIfChanged = false; stopIfChanged = false` — a rebuild must not
  trigger a backup.
- `Nice = 10` and `IOSchedulingClass = "idle"` — stay out of the way of
  whatever the machine is doing; `UMask = "0077"` so any files the run
  creates are private.
- The shutdown unit uses the same stop trick as git-sync, but guards the
  work: `ExecStop` runs `if [ "$(systemctl is-system-running)" = stopping ];
  then exec exe; fi` — so a manual `systemctl stop` does not back up, only a
  real shutdown. `PRUNE = "0"` in its environment, so the shutdown run backs
  up but does not prune.
- `Persistent = true` on the timer is why the schedule description says
  missed runs are made up at next boot.

In the script:

- `trap 'exit 143' TERM` / `trap 'exit 130' INT HUP` — report the standard
  signal exit codes so a killed run is visible.
- Repository state is probed with `restic unlock || true; restic cat config`:
  rc 0 means initialized, rc 10 triggers `restic init` plus an ntfy "restic
  repo created" — *"# restic >= 0.17 exits 10 when the repository is
  reachable but not initialized; any other non-zero exit is a hard failure."*
- The mount check walks *up* the repository path — *"so a subdirectory of a
  mounted share still counts as mounted, but never accept `/`"* — else it
  notifies failure "share not mounted".
- A backup exit code of 3 is tolerated (`if (( rc != 0 && rc != 3 ))`);
  forget/prune runs with `--retry-lock 15m` so it waits rather than
  colliding with another lock.
- `notify()` retries with `--retry-all-errors --max-time 20` and only warns
  on failure — a missing notification must never fail the backup.

## Why the design

Restic is the heavyweight backup for the fleet: encrypted, deduplicated,
with retention. The exit-code handling (10 → auto-init, 3 → tolerated) is
the specific restic protocol the script encodes so first runs and partial
errors behave sanely. `Persistent = true` plus the shutdown run cover the
fleet reality that machines are often off when their daily timer would
fire. The shared lockfile plus `flock` is what keeps the daily and shutdown
runs from corrupting each other, and the ntfy failure unit exists because a
silent failed backup is the one failure mode nobody on the LAN would
otherwise notice.
