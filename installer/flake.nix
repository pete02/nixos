{
  description = "Custom NixOS installation ISO with private config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    # Your private repo
    myconfig.url = "github:pete02/nixos";
    myconfig.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, myconfig }: {
    nixosConfigurations.installIso = nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
      modules = [
        # Base minimal installer module
        ({ modulesPath, pkgs, ... }: {
          imports = [ (modulesPath + "/installer/cd-dvd/installation-cd-minimal-new-kernel-no-zfs.nix") ];
          nix.settings.experimental-features = [
            "nix-command"
            "flakes"
          ];
          environment.etc."git-source".source = myconfig.outPath;
          boot.supportedFilesystems = [ "bcachefs" ];
          # Optional: Add your install script
          environment.systemPackages = [
            pkgs.git
            (pkgs.writeShellScriptBin "format-drives" ''
                #!/usr/bin/env bash
set -euo pipefail
echo "=== NixOS bcachefs automatic setup ==="

# --- Step 1: Detect drives ---
echo "[*] Detecting available drives..."
lsblk -d -o NAME,SIZE,MODEL,TYPE

# Expected devices
HDD=$(lsblk -dno NAME,SIZE | grep "2T" | awk '{print $1}' || true)
SSD=$(lsblk -dno NAME,SIZE | grep "500G" | awk '{print $1}' || true)

if [[ -z "$HDD" || -z "$SSD" ]]; then
  echo "[-] Could not automatically detect drives by size!"
  echo "    Please edit the script to set HDD and SSD manually."
  exit 1
fi

echo "[+] Found HDD: /dev/$HDD"
echo "[+] Found SSD: /dev/$SSD"
echo
read -p "⚠️  This will ERASE ALL DATA on /dev/$HDD and /dev/$SSD. Type YES to continue: " confirm
[[ "$confirm" == "YES" ]] || { echo "Aborted."; exit 1; }

# --- Step 2: Unmount any existing mounts ---
echo "[*] Unmounting any existing partitions..."
umount -R /mnt || true
swapoff -a || true

# --- Step 3: Partition the HDD (data) ---
echo "[*] Partitioning HDD (/dev/$HDD)..."
parted -s /dev/$HDD mklabel gpt
parted -s /dev/$HDD mkpart primary 1MiB 100%

# --- Step 4: Partition the SSD (EFI + cache) ---
echo "[*] Partitioning SSD (/dev/$SSD)..."
parted -s /dev/$SSD mklabel gpt
parted -s /dev/$SSD mkpart ESP fat32 1MiB 512MiB
parted -s /dev/$SSD set 1 esp on
parted -s /dev/$SSD mkpart primary 512MiB 100%

# --- Step 5: Format EFI partition ---
echo "[*] Formatting EFI partition..."
mkfs.fat -F 32 -n boot /dev/$${SSD}p1

# --- Step 6: Create bcachefs filesystem ---
echo "[*] Creating bcachefs filesystem..."
mkfs.bcachefs -L nixos /dev/$${SSD}p2 /dev/$${HDD}1

# --- Step 7: Mount filesystems ---
echo "[*] Mounting filesystems..."
mount /dev/$${SSD}p2 /mnt
mkdir -p /mnt/boot
mount /dev/disk/by-label/boot /mnt/boot

# --- Step 8: Verify mounts ---
echo "[*] Verifying mounts..."
echo
lsblk -o NAME,MOUNTPOINT,FSTYPE,LABEL,SIZE
echo
df -h /mnt || { echo "[-] Mount verification failed!"; exit 1; }

# --- Step 9: Generate NixOS configuration ---
echo "[*] Generating NixOS configuration..."
nixos-generate-config --root /mnt
echo
echo "Done!"
echo
echo "Then run: nixos-install"
            '')
          ];
        })
      ];
    };
  };
}
