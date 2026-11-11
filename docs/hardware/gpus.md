# GPUs — `hardware-gpus`

`modules/features/hardware/gpus.nix`. One module covers all GPU
configuration, with three mutually exclusive options.

## Options

- `hardware-gpus.nvidia` — NVIDIA, stable driver.
- `hardware-gpus.nvidia-legacy` — *"NVIDIA GPU (legacy driver for GTX
  900/1000 series)."*
- `hardware-gpus.amd` — AMD GPU.

These are under a **hyphenated namespace**: hosts write
`hardware-gpus.nvidia = true;` (aria uses `nvidia-legacy`, raysha uses
`nvidia`).

## What it sets, and why

- An assertion enforces exclusivity: `lib.count lib.id [nvidia nvidia-legacy
  amd] <= 1` — *"# GPU (mutually exclusive, enforced by the assertions
  below)"* — because loading two vendor stacks at once is incoherent.
- `commonGraphics` — *"Settings shared by every GPU vendor"* — turns on
  `hardware.graphics` with `enable32Bit = true` (32-bit GL is what Steam
  and old games need).
- `mkNvidiaConfig = package:` — *"Everything the stable and legacy NVIDIA
  setups have in common; only the driver package differs."* Stable passes
  `config.boot.kernelPackages.nvidiaPackages.stable`; legacy passes
  `legacy_580` — the 580 series is the last driver branch supporting GTX
  900/1000-series cards, which is why that option exists at all.
- The NVIDIA block: `videoDrivers = ["nvidia"]`, the
  `nvidia-container-toolkit` package plus its `hardware.` option (so Podman
  containers can use the GPU), `modesetting.enable = true`,
  `open = false` (open kernel drivers don't support the older cards this
  fleet's NVIDIA hosts have), `powerManagement.enable = false` (left to
  the compositor / `power` feature instead), and `nvidiaSettings = true`
  (ships the settings UI).
- `boot.kernelModules` + `initrd.kernelModules` load `nvidia`,
  `_modeset`, `_uvm`, `_drm` early — in the initrd too, so the splash and
  boot already run on the GPU. `kernelParams` add `nvidia-drm.modeset=1`,
  which is what makes Wayland compositors (Hyprland) work on NVIDIA.
- Cross-vendor blacklisting: NVIDIA hosts blacklist `amdgpu`, AMD hosts
  blacklist all four `nvidia*` modules — dead vendor modules must not load.
- The AMD branch: `videoDrivers = ["amdgpu"]`, `hardware.amdgpu.opencl.enable`
  (GPU compute for RPCS3/Steam), `initrd.enable = true`, and `amdgpu` in
  `kernelModules`.

## Why the design

One module instead of three so the shared bits (graphics libs,
blacklisting the *other* vendor) can't drift apart; the `package`
parameter is the single axis on which stable and legacy NVIDIA differ,
which is exactly why the fleet can offer a legacy option for older cards
without duplicating the driver stack.
