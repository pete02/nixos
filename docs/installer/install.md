# `nixos-installer` — the install tool

Leaf doc. `modules/installer/_package.nix` builds a `writeShellScriptBin`
wrapper around `nixos-installer.sh`; `apps.installer` runs it from the flake,
and the ISO ships it as a system package.

## Why the wrapper exists

```
export BUNDLED_FLAKE=${bundledFlake}
exec bash ${./nixos-installer.sh} "$@"
```

`bundledFlake = self`, so the package **embeds the whole flake's source tree
into its own store path** — on the ISO, where there is no git checkout, the
script still finds a flake: `resolve_flake` tries `$INSTALLER_FLAKE`, then
`./flake.nix` if you happen to be in a repo, then `$BUNDLED_FLAKE`. That is the
"# The wrapper embeds this whole flake's source, so it ships on the ISO."
comment in `iso-x86.nix`. The wrapper also prepends `makeBinPath` of its
dependency list (coreutils, util-linux, gptfdisk, parted, dosfstools, e2fsprogs,
zstd, …) to `PATH`, so the script works on a minimal ISO without hunting for
tools.

## Commands

- `list`, `build <target>` — targets map to flake attrs: `iso-x86` → the ISO
  config, `rpi3`/`rpi5` → the `sd-rpi3`/`sd-rpi5` image packages. Building an
  rpi target cross-architectures, so the script warns (not fails) if no aarch64
  builder is available — it checks binfmt's `qemu-aarch64`, `/etc/nix/machines`
  for an `aarch64-linux` builder, and `extra-platforms`, matching how Nix itself
  decides.
- `flash <target|file> <dev>` — `zstd -dc` for `.zst` images else `dd bs=4M
  conv=fsync`, then `sync` + `partprobe` + `udevadm settle` so the kernel re-reads
  the partition table before anything else touches the device.

## Device safety (`flash`)

Before writing, `confirm_device` refuses unless the path is a whole block
device (not a partition), refuses if the device currently holds `/`, `/iso`,
`/nix/store` or `/nix/.ro-store` (you are about to overwrite the system you are
running), prints `lsblk` of it, and makes you type the device path back unless
`-y` was passed. `release_device` then unmounts its partitions **in reverse
order** (`tac`) — deepest mountpoint first, since you cannot unmount a parent
before its children. `part()` appends `p` for nvme/mmcblk-style names
(`nvme0n1` + `p1`), the standard quirk of bare-disk naming.

## `install <dev> [host]`

Root and UEFI are hard requirements — `[[ -d /sys/firmware/efi ]]` with the
comment "this layout is UEFI-only", because the partitioning below assumes an
EFI boot loader. `host` must have a `modules/installer/_hosts/<host>.nix` to
boot into.

The disk layout, written fresh after `wipefs -a` + `sgdisk --zap-all`:

```
sgdisk -n1:0:+1G -t1:ef00 -c1:ESP -n2:0:0 -t2:8300 -c2:nixos
```

- Partition 1: fixed **1 GiB** FAT32 ESP (label `NIXOS_BOOT`) — sized for
  systemd-boot plus generations, and small boot partitions are exactly why
  [gitops keeps generation counts low](nixos-management.md).
- Partition 2: the rest, ext4 label `nixos`.

Then:

1. Mount root at `/mnt`, ESP at `/mnt/boot` (mounted `umask=0077` so EFI
   stubs/generations aren't world-writable).
2. `tar` the flake source into `/mnt/etc/nixos` — excluding `.git` and
   `result*` symlinks, normalizing ownership — so the installed system *is*
   this repo, and future rebuilds use `--flake /etc/nixos#<host>` like every
   fleet machine.
3. `nixos-generate-config --show-hardware-config >
   modules/installer/_hardware/<host>.nix` — the generated disk config the
   [images doc](images.md) describes; the installed `<host>.nix` reads it back
   via its `hasHw` gate.
4. `nixos-install --root /mnt --flake /mnt/etc/nixos#<host> --no-root-passwd`
   — no root password because the wheel user logs in with the configured keys
   ([settings](images.md)).

## After installing

The installed system joins the fleet; the next steps are the repo's normal
ones — rebuild the host, then the [keys/bootstrap tooling](tools.md) if its
identity is new.
