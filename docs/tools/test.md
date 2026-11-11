# `test.sh` — rebuild with a logged summary

Leaf doc. The rebuild entry point for the fleet: pick a host, run
`nixos-rebuild switch`, keep a log you can actually read afterwards.

## Shape

Re-execs under sudo (`exec sudo -- "$0" "$@"` — a rebuild needs root), `cd
/etc/nixos`, then **asks the flake what to offer**:

```
nix eval --json '.#nixosConfigurations' --apply builtins.attrNames
```

Same pattern as [regen_keys](keys.md): the host list is never hardcoded here —
the [host default.nix files](hosts.md) (via `mkHost`/`mkRpiHost`) are the source
of truth, so the menu can't drift.

The target must be in that list or the script exits — typos never reach
`nixos-rebuild`.

## The rebuild itself

```
nixos-rebuild switch --flake /etc/nixos#$TARGET 2>&1 | tee "$LOG_FILE"
```

- `2>&1 | tee` — stdout *and* stderr land in the log while still streaming to
  the terminal.
- `STATUS=${PIPESTATUS[0]}` captures nixos-rebuild's exit code, not tee's; the
  surrounding `set +e … set -e` lets the pipeline fail without tripping
  `pipefail` before the summary is written.

## Why the log exists

Logs go to `rebuild-logs/<host>-<timestamp>.log` under the repo. Rebuilds fail
mid-deployment surprisingly often (network down, cache unreachable, eval error
from one feature module); the log plus the appended **summary block** —

```
===== Rebuild summary =====
Host / Started / Finished / Elapsed / Exit status
```

— answers "what happened at 03:14" without re-running anything. The same block
is `tee -a`-appended to the log, so the file is self-describing: grep for the
exit status, check elapsed time for how long the build ran.

## Exit-code passthrough

The script ends `exit "$STATUS"` — `test.sh`'s own exit code *is* the rebuild's,
so it composes in CI or chains (`test.sh aria && notify`) without parsing the log.

## Related

The flake's own runtime auto-rebuild ([nixos-management](nixos-management.md))
logs through systemd and notifies ntfy on failure; `test.sh` is the
human-initiated counterpart with the same logging idea.
