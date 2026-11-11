# CachyOS kernel — `hardware-cachyoskernel`

`modules/features/hardware/cachyoskernel.nix`. Option `hardware.cachyos-kernel`.

## What it sets, and why

- The kernel comes from a dedicated flake input,
  `inputs.nix-cachyos-kernel`, pinned to
  `linux-cachyos-latest-zen4` for the host platform's system — CachyOS
  ships a kernel with the `zen4` scheduler/tuning defaults, chosen for
  desktop latency on this fleet's x86 hardware.
- `kernelPackages = pkgs.linuxPackagesFor kernel` — every userspace piece
  that pairs with the kernel (headers, libc selection) is derived from the
  same kernel, so the two can't skew.
- `boot.extraModulePackages = [kernelPackages.r8125]` — the RME RME
  Radium ONE/Two (r8125) ALSA driver isn't in the mainline kernel image,
  so it's built as an out-of-tree module against the CachyOS kernel.
  (A fleet machine has one of those cards.)

## Why the design

A non-distro kernel is risky if the toolchain disagrees with it, which is
why `linuxPackagesFor` ties the package set to the exact kernel rather than
using default `linuxPackages`. The option is opt-in per host: Pi hosts can't
use it (the input is x86-tuned), so hosts that want the stock kernel simply
don't enable it.
