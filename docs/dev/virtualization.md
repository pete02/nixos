# Dev virtualization — `dev-virtualization`

`modules/features/dev/virtuallization.nix` (note the filename typo — `virtuallization`
with three `l`s; the module attr is still `dev-virtualization`). KVM + libvirt.

## Options

- `dev.virtualization` — enable virtualization.

## What it sets, and why

- `boot.kernelModules = ["kvm-intel" "kvm-amd"]` — loads **both** KVP vendor
  modules; the one that doesn't match the CPU simply fails to load harmlessly,
  so listing both covers Intel and AMD hosts without per-host branching.
- `virtualisation.libvirtd` with:
  - `qemu.package = pkgs.qemu_kvm` — QEMU built with KVM acceleration.
  - `qemu.runAsRoot = true` — QEMU helper runs as root (needed for the
    privileged x86 emulation path).
  - `swtpm.enable = true` — comment `# TPM support (useful for modern OSes)`:
    a software TPM so guests can present a TPM, which modern OSes (Windows 11,
    recent kernels) require to boot.
- `networking.firewall.trustedInterfaces = ["virbr0"]` — libvirt's default
  guest network `virbr0` is trusted through the firewall so guests get network.
- GUI + support packages: `virt-manager`, `virt-viewer`, `spice`, `spice-gtk`,
  `virtio-win`, `dnsmasq` (`spice*` = the display protocol clients, `virtio-win`
  = guest drivers, `dnsmasq` = libvirt's name-resolution helper).
- user in `libvirtd` and `kvm` groups — access to the daemon and the KVM device.
- `security.polkit.enable = true` — desktop apps (virt-manager) use polkit to
  access `/dev` and the daemon without sudo.
- `boot.kernel.sysctl."net.ipv4.ip_forward" = 1` — libvirt builds guest
  networking by forwarding IPs into the host's network; forwarding must be on.

## Why the design

The `swtpm` flag exists specifically because the fleet boots modern operating
systems in VMs, which refuse to run without a TPM. `ip_forward` and
`trustedInterfaces=["virbr0"]` are the two halves of libvirt's guest-network
plumbing (kernel forwarding + firewall allowance) — set together so a guest's
network survives the firewall.
