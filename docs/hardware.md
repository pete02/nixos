# Hardware — `hardware`

`modules/features/hardware/default.nix` imports five submodules, in file
order: `hardware-gpus`, `hardware-cachyoskernel`, `hardware-peripherals`,
`hardware-mdadm`, `hardware-gpucooler`. Every host inherits the aggregator
through `mkHost`'s feature-module list; each submodule is inert until its
option is enabled, so a host only pays for the hardware it actually has.

The grouping exists because these are per-machine physical concerns — the
GPU stack, the kernel, input devices, RAID arrays, fan control — things no
other feature category covers.

- [GPUs](gpus.md) — NVIDIA (stable or legacy) vs AMD, mutually exclusive.
- [CachyOS kernel](cachyoskernel.md) — `hardware.cachyos-kernel`, the
  zen4 kernel + `r8125` audio module.
- [mdadm](mdadm.md) — `hardware.mdadm`, just the mdadm tool for the RAID
  arrays the fleet's disks use.
- [Peripherals](peripherals.md) — Logitech (`logiops`/`piper`/`ratbagd`)
  and Razer RGB support.
- [GPU cooler](gpu-cooler.md) — `hardware.gpu-cooler`, a fan-control
  daemon looping on `nvidia-smi` temperature.

Namespace caveat: the GPU module's options live under a hyphenated
namespace — hosts write `hardware-gpus.nvidia = true;`, not
`hardware.nvidia` — while its siblings use plain `hardware.*`.
