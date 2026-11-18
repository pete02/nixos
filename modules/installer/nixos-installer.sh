#!/usr/bin/env bash
# nixos-installer: build images, flash drives, and install NixOS from this flake.
set -euo pipefail

ASSUME_YES=0
SUDO=""
[[ $EUID -eq 0 ]] || SUDO="sudo"

die()  { echo "error: $*" >&2; exit 1; }
warn() { echo "warning: $*" >&2; }

usage() {
  cat <<USAGE
Usage: nixos-installer [-y] <command> [args]

Commands:
  list                         Show targets
  build <target>               Build an image (iso | rpi3 | rpi5); prints the image path
  flash <target|file> <dev>    Build (if needed) and write an image to a drive. ERASES <dev>.
                               e.g. flash iso /dev/sdb     |   flash rpi5 /dev/mmcblk0
  install <dev> [host]         x86 only, run from the live ISO as root. Partitions <dev>
                               (GPT: 1G ESP + ext4 root), generates hardware config,
                               and nixos-install --flake. Default host: x86. ERASES <dev>.

Flake used: \$INSTALLER_FLAKE, else ./ if it has a flake.nix, else the copy bundled with this tool.
Options: -y/--yes skips the typed confirmation.
USAGE
  exit "${1:-1}"
}

resolve_flake() {
  if   [[ -n ${INSTALLER_FLAKE:-} ]]; then FLAKE=$INSTALLER_FLAKE
  elif [[ -f ./flake.nix ]];          then FLAKE=$PWD
  elif [[ -n ${BUNDLED_FLAKE:-} ]];   then FLAKE=$BUNDLED_FLAKE
  else die "no flake found (set INSTALLER_FLAKE or cd into the repo)"; fi
}

# True if this machine can build aarch64: qemu binfmt, or a configured remote builder.
have_aarch64_builder() {
  [[ -e /proc/sys/fs/binfmt_misc/qemu-aarch64 ]] && return 0
  grep -qs aarch64-linux /etc/nix/machines && return 0
  { nix config show 2>/dev/null || nix show-config 2>/dev/null; } | grep -E '^(builders|extra-platforms|extra-sandbox-paths)' | grep -q aarch64 && return 0
  return 1
}

# Sets IMAGE to the built image file.
build_target() {
  local target=$1 attr sub pat
  case $target in
    iso|iso-x86|x86-iso) attr=iso; sub=iso; pat='*.iso' ;;
    rpi3)                attr=sd-rpi3; sub=sd-image; pat='*.img*' ;;
    rpi5)                attr=sd-rpi5; sub=sd-image; pat='*.img*' ;;
    *) die "unknown target '$target' (try: iso, rpi3, rpi5)" ;;
  esac
  if [[ $target == rpi* && $(uname -m) != aarch64 ]] && ! have_aarch64_builder; then
    warn "no aarch64 builder detected (binfmt/qemu or a remote builder in /etc/nix/machines); the build may fail"
  fi
  resolve_flake
  echo ">> nix build --extra-substituters \"\" $FLAKE#$attr" >&2
  local out
  out=$(nix build --extra-substituters "" "$FLAKE#$attr" --out-link "result-$attr" --print-out-paths)
  IMAGE=$(find -L "$out/$sub" -maxdepth 1 -type f -name "$pat" | head -n1)
  [[ -n $IMAGE ]] || die "no image found under $out/$sub"
}

confirm_device() {
  local dev=$1 m src ans
  [[ -b $dev ]] || die "$dev is not a block device"
  [[ $(lsblk -dno TYPE "$dev") == disk ]] || die "$dev is not a whole disk (use e.g. /dev/sdb, not /dev/sdb1)"
  for m in / /iso /nix/store /nix/.ro-store; do
    src=$(findmnt -no SOURCE "$m" 2>/dev/null || true)
    if [[ -n $src ]] && lsblk -nrpo NAME "$dev" | grep -qxF "${src%%[*}"; then
      die "$dev holds $m (the running system / installer medium); refusing"
    fi
  done
  lsblk -o NAME,SIZE,MODEL,TRAN,FSTYPE,LABEL,MOUNTPOINTS "$dev"
  if [[ $ASSUME_YES -ne 1 ]]; then
    read -r -p "This will ERASE ALL DATA on $dev. Type the device path to continue: " ans
    [[ $ans == "$dev" ]] || die "aborted"
  fi
}

release_device() {
  local dev=$1 p
  while read -r p; do
    $SUDO umount "$p" 2>/dev/null || true
  done < <(lsblk -nrpo NAME "$dev" | tail -n +2 | tac)
}

settle() {
  $SUDO partprobe "$1" 2>/dev/null || true
  udevadm settle 2>/dev/null || true
}

cmd_list() {
  cat <<TARGETS
iso      Live installer ISO for x86_64 UEFI machines (use 'install' from inside it)
rpi3     Raspberry Pi 3 SD image (full system, flash directly)
rpi5     Raspberry Pi 5 SD image (full system, flash directly)
TARGETS
}

cmd_build() {
  [[ $# -eq 1 ]] || usage
  build_target "$1"
  echo "$IMAGE"
}

cmd_flash() {
  [[ $# -eq 2 ]] || usage
  local what=$1 dev=$2
  if [[ -f $what ]]; then IMAGE=$what; else build_target "$what"; fi
  confirm_device "$dev"
  release_device "$dev"
  echo ">> writing $IMAGE -> $dev"
  case $IMAGE in
    *.zst) zstd -dc "$IMAGE" | $SUDO dd of="$dev" bs=4M iflag=fullblock conv=fsync status=progress ;;
    *)     $SUDO dd if="$IMAGE" of="$dev" bs=4M conv=fsync status=progress ;;
  esac
  sync
  settle "$dev"
  echo ">> done. Pi images grow the root filesystem on first boot."
}

part() { # part <dev> <n>  -> /dev/sdb1 or /dev/nvme0n1p1
  if [[ $1 == *[0-9] ]]; then echo "${1}p$2"; else echo "${1}$2"; fi
}

cmd_install() {
  [[ $# -ge 1 && $# -le 2 ]] || usage
  local dev=$1 host=${2:-x86}
  [[ $EUID -eq 0 ]] || die "run as root (sudo nixos-installer install ...)"
  [[ -d /sys/firmware/efi ]] || die "not booted in UEFI mode; this layout is UEFI-only"
  command -v nixos-install >/dev/null || die "nixos-install not found; run this from the live ISO"
  resolve_flake
  
  # Check against flake outputs or standard host path instead of hardcoded installer path
  nix eval "$FLAKE#nixosConfigurations.$host" >/dev/null 2>&1 || die "host '$host' not found in flake nixosConfigurations"

  confirm_device "$dev"
  release_device "$dev"
  swapoff -a 2>/dev/null || true

  echo ">> partitioning $dev"
  wipefs -a "$dev"
  sgdisk --zap-all "$dev"
  sgdisk -n1:0:+1G -t1:ef00 -c1:ESP -n2:0:0 -t2:8300 -c2:nixos "$dev"
  settle "$dev"
  local esp root
  esp=$(part "$dev" 1); root=$(part "$dev" 2)
  for _ in $(seq 20); do [[ -b $esp && -b $root ]] && break; sleep 0.5; done

  echo ">> formatting"
  mkfs.fat -F32 -n NIXOS_BOOT "$esp"
  mkfs.ext4 -F -L nixos "$root"

  echo ">> mounting"
  mount "$root" /mnt
  mkdir -p /mnt/boot
  mount -o umask=0077 "$esp" /mnt/boot

  echo ">> copying flake to /mnt/etc/nixos"
  mkdir -p /mnt/etc/nixos
  tar -C "$FLAKE" --exclude=.git --exclude='result*' --mode='u+rwX' --owner=0 --group=0 -cf - . \
    | tar -C /mnt/etc/nixos -xf -

  echo ">> generating hardware configuration"
  nixos-generate-config --root /mnt --show-hardware-config \
    > "/mnt/etc/nixos/_hosts/hardware-$host.nix" # or save it where your host expects it

  echo ">> nixos-install --flake /mnt/etc/nixos#$host"
  nixos-install --root /mnt --flake "/mnt/etc/nixos#$host" --no-root-passwd

  echo ">> installed. Log in, then reboot."
}

# --- arg parsing -------------------------------------------------------------
args=()
for a in "$@"; do
  case $a in
    -y|--yes) ASSUME_YES=1 ;;
    -h|--help) usage 0 ;;
    *) args+=("$a") ;;
  esac
done
set -- "${args[@]}"
[[ $# -ge 1 ]] || usage
cmd=$1; shift
case $cmd in
  list)    cmd_list ;;
  build)   cmd_build "$@" ;;
  flash)   cmd_flash "$@" ;;
  install) cmd_install "$@" ;;
  *)       usage ;;
esac