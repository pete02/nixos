# git-sync — `backups-git-sync`

`modules/features/backups/git-sync/default.nix` plus
`modules/features/backups/git-sync/git-sync.sh`. Commits and pushes every
git repository found under a set of folders, at shutdown.

## Options

- `backups.git-sync.enable`
- `backups.git-sync.user` — whose `~/.gitconfig` and credentials are used
  (defaults to `config.username`).
- `backups.git-sync.folders` — e.g. `/home/alice/code`; must be non-empty
  (assertion).
- `backups.git-sync.depth` — how deep to search for repos (positive int,
  default 3).
- `backups.git-sync.commitMessage` — `null` means "Auto-commit:
  <timestamp>".
- `backups.git-sync.timeout` — "Maximum time the sync may delay shutdown"
  (default `2min`).

## What it sets, and why

- The runner is built with `self.lib.mkScript`, so its `# runtimeInputs`
  (`coreutils curl git gnugrep findutils gnused openssh`) are the
  build-time-checked command set — the script's own `check()` proves every
  command it needs was declared.
- `systemd.services.git-sync` is the shutdown trick: the unit "starts" at
  boot doing nothing (`ExecStart = /bin/true`, `RemainAfterExit`) and does
  its work in `ExecStop`, which systemd runs on shutdown/reboot. The code
  comment spells out the reason: *"The unit 'starts' at boot (doing nothing)
  and does its work when it is stopped, which systemd does on shutdown/reboot.
  Stop order is the reverse of start order, so ordering it after the network
  means the sync runs while the network is still up."* Hence
  `after = [network-online.target nss-lookup.target local-fs]`.
- `restartIfChanged = false; stopIfChanged = false` — *"Do not run the sync
  (i.e. stop the unit) on `nixos-rebuild switch`."* Otherwise every rebuild
  would push during the switch.
- `GIT_TERMINAL_PROMPT = "0"` — *"Never hang a prompt during shutdown"* —
  and `GIT_SSH_COMMAND` with `BatchMode=yes -o ConnectTimeout=10`, so a
  dead network fails fast instead of blocking power-off.
- `TimeoutStopSec = timeout` caps how long the sync may delay shutdown.

In the script:

- Repo discovery is `find "$root" -maxdepth "$((DEPTH + 1))" -name .git
  -prune -print` — *"A repo is any directory containing a .git entry (dir or
  file, so worktrees and submodules count). -prune stops find from
  descending into .git itself."* The `+ 1` is why `depth 3` finds repos up
  three folders deep.
- Detached HEAD is skipped (`git symbolic-ref --short -q HEAD`); repos with
  no remote are skipped; a failure in one repo does not stop the others.
- Repos with nothing to commit are still pushed if they have unpushed
  commits — the sync is about shipping work, not manufacturing commits.
- `--check` is handled before `getopts` because it is a long option.

## Why the design

Shutdown is the one moment the machine is guaranteed to be idle and its
work finished, so the sync piggybacks on systemd's stop ordering — and
because stop ordering is the *reverse* of start ordering, the unit must be
ordered *after* the network to still have network at stop time. Everything
prompt-related (`GIT_TERMINAL_PROMPT`, `BatchMode`, `ConnectTimeout`, the
2-minute cap) exists because a hanging sync would hold up shutdown
across the fleet.
