# GPU cooler — `hardware-gpucooler`

`modules/features/hardware/gpu-cooler/default.nix` plus
`gpu-cooler.sh`. Option `hardware.gpu-cooler` (note the module attr is
`hardware-gpucooler`, one word — the option keeps the hyphen).

## What it sets, and why

- The runner is `self.lib.mkScript` with runtimeInputs
  `python313Packages.gputil`, `config.hardware.nvidia.package.bin`, and
  `gawk` — the NVIDIA userspace binary comes from whichever driver the
  `hardware-gpus` module selected (stable or legacy), so the cooler follows
  the host's driver choice instead of pinning one.
- `systemd.services.gpu-fan-control` runs it with `Restart = "always"` and
  `RestartSec = 1`: the script is an infinite loop, so a restart-on-crash
  policy is the only way to keep fan control alive after a transient
  failure.

In the script:

- `--check` verifies `nvidia-smi` and `awk` exist (the `mkScript` build-time
  check proves the declared runtimeInputs cover it).
- It enables manual PWM control on `hwmon1`'s `pwm2`/`pwm5` fans, then
  loops: query `nvidia-smi` temperature, clamp to 40–80 °C, and pick
  `speed = 40` below 55 °C (*"very quiet fixed speed"*) or `255` above —
  binary throttle, not a ramp.
- Honest caveats found in the source: the script carries a
  `# TODO: write PWM to correct hwmon path` comment (the hwmon indices are
  hardcoded for the one machine that uses it), and its `check()` error
  messages still say `bitwarden-backup:` — the script was forked from the
  bitwarden backup, including a leftover *"Notifications are best-effort"*
  comment. It has no ntfy integration.

## Why the design

The fleet's NVIDIA box has chassis fans wired to the hwmon PWM interface
rather than trusting the driver's thermal curve, so a tiny supervised loop
re-reads the GPU temperature each second and sets the fans — cheap and
obvious where a tuned daemon would be opaque. The hardcoded `hwmon1` paths
are the known rough edge: it is a per-machine hack, enabled only on that
machine.
