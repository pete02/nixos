{
  description = "Raysha recovery/install ISO";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

  };

  outputs = {
    self,
    nixpkgs,
  }: {
    nixosConfigurations.rayshaRecovery = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";

      modules = [
        (
          {
            modulesPath,
            pkgs,
            ...
          }: {
            imports = [
              (modulesPath + "/installer/cd-dvd/installation-cd-minimal-new-kernel-no-zfs.nix")
            ];

            nix.settings.experimental-features = [
              "nix-command"
              "flakes"
            ];

            # Bake the current configuration into the ISO.
            #
            # This is a snapshot of the myconfig input used when the ISO
            # is built. It does not depend on GitHub being reachable when
            # raysha is being recovered.
            environment.etc."raysha-config".source = /etc/nixos;
            environment.etc."sops/age/keys.txt".source = ./keys.txt;
            environment.systemPackages = with pkgs; [
              git
              mdadm
              parted
              dosfstools
              e2fsprogs
              util-linux
              gptfdisk
              pciutils
              usbutils

              (writeShellScriptBin "raysha-install" ''
                #!/usr/bin/env bash
                set -euo pipefail

                TARGET="/mnt"
                RAID="/dev/md0"
                CONFIG="/etc/raysha-config"

                echo
                echo "=============================================="
                echo "          RAYSHA RECOVERY / INSTALL"
                echo "=============================================="
                echo
                echo "This will completely ERASE three drives and"
                echo "create a new three-device RAID0."
                echo
                echo "Target layout:"
                echo
                echo "  Samsung 970 EVO Plus 2TB"
                echo "    EFI + RAID member"
                echo
                echo "  Samsung 860 EVO 1TB"
                echo "    RAID member"
                echo
                echo "  Corsair Force MP600 1TB"
                echo "    RAID member"
                echo
                echo "  RAID0 / 512 KiB chunks / mdadm metadata 1.2"
                echo "  ext4 filesystem"
                echo

                echo "Current drives:"
                echo
                lsblk -o NAME,SIZE,MODEL,SERIAL,TYPE,MOUNTPOINTS
                echo

                # ---------------------------------------------------------
                # Locate the intended drives.
                #
                # We deliberately do not assume /dev/sda or /dev/nvme0n1.
                # ---------------------------------------------------------

                find_disk() {
                  local pattern="$1"

                  mapfile -t matches < <(
                    lsblk -dnpo NAME,MODEL |
                    awk -v pattern="$pattern" '
                      index(tolower($0), tolower(pattern)) {
                        print $1
                      }
                    '
                  )

                  if (( ''${#matches[@]} != 1 )); then
                    echo
                    echo "ERROR: Could not uniquely identify:"
                    echo "  $pattern"
                    echo
                    echo "Matches:"
                    printf '  %s\n' "''${matches[@]}"
                    echo
                    exit 1
                  fi

                  printf '%s\n' "''${matches[0]}"
                }

                NVME2T="$(find_disk 'Samsung SSD 970 EVO Plus')"
                SAMSUNG1T="$(find_disk 'Samsung SSD 860 EVO')"
                FORCE1T="$(find_disk 'Force MP600')"

                # ---------------------------------------------------------
                # Safety checks
                # ---------------------------------------------------------

                for disk in "$NVME2T" "$SAMSUNG1T" "$FORCE1T"; do
                  if [[ "$(lsblk -dnro TYPE "$disk")" != "disk" ]]; then
                    echo "ERROR: $disk is not a whole disk."
                    exit 1
                  fi
                done

                if [[ "$NVME2T" == "$SAMSUNG1T" ||
                      "$NVME2T" == "$FORCE1T" ||
                      "$SAMSUNG1T" == "$FORCE1T" ]]; then
                  echo "ERROR: Multiple drives resolved to the same device."
                  exit 1
                fi

                echo
                echo "=============================================="
                echo "             DRIVES TO BE ERASED"
                echo "=============================================="
                echo
                echo "  EFI + RAID : $NVME2T"
                echo "  RAID       : $SAMSUNG1T"
                echo "  RAID       : $FORCE1T"
                echo
                echo "These drives will be irreversibly erased."
                echo

                read -r -p \
                  'Type RAYSHA-YES-ERASE to continue: ' confirmation

                if [[ "$confirmation" != "RAYSHA-YES-ERASE" ]]; then
                  echo
                  echo "Aborted."
                  exit 1
                fi

                # ---------------------------------------------------------
                # Cleanup
                # ---------------------------------------------------------

                echo
                echo "[1/8] Cleaning existing mounts and RAID..."

                umount -R "$TARGET" 2>/dev/null || true
                swapoff -a 2>/dev/null || true

                if [[ -e "$RAID" ]]; then
                  mdadm --stop "$RAID" 2>/dev/null || true
                fi

                # ---------------------------------------------------------
                # Partition disks
                # ---------------------------------------------------------

                echo "[2/8] Partitioning Samsung 970 EVO Plus..."

                parted -s "$NVME2T" mklabel gpt
                parted -s "$NVME2T" mkpart ESP fat32 1MiB 1025MiB
                parted -s "$NVME2T" set 1 esp on
                parted -s "$NVME2T" mkpart RAID 1025MiB 100%

                echo "[3/8] Partitioning Samsung 860 EVO..."

                parted -s "$SAMSUNG1T" mklabel gpt
                parted -s "$SAMSUNG1T" mkpart RAID 1MiB 100%

                echo "[4/8] Partitioning Force MP600..."

                parted -s "$FORCE1T" mklabel gpt
                parted -s "$FORCE1T" mkpart RAID 1MiB 100%

                partprobe "$NVME2T"
                partprobe "$SAMSUNG1T"
                partprobe "$FORCE1T"
                udevadm settle
                part() {
                  if [[ "$1" =~ [0-9]$ ]]; then echo "''${1}p$2"; else echo "''${1}$2"; fi
                }

                EFI="$(part "$NVME2T" 1)"
                RAID_A="$(part "$NVME2T" 2)"
                RAID_B="$(part "$SAMSUNG1T" 1)"
                RAID_C="$(part "$FORCE1T" 1)"

                echo
                echo "Resulting partitions:"
                lsblk -o NAME,SIZE,TYPE,FSTYPE,PARTTYPE \
                  "$NVME2T" "$SAMSUNG1T" "$FORCE1T"
                echo

                # ---------------------------------------------------------
                # EFI
                # ---------------------------------------------------------

                echo "[5/8] Formatting EFI..."

                mkfs.fat -F 32 -n EFI "$EFI"

                # ---------------------------------------------------------
                # RAID0
                # ---------------------------------------------------------

                echo "[6/8] Creating RAID0..."

                mdadm --zero-superblock \
                  "$RAID_A" "$RAID_B" "$RAID_C" \
                  2>/dev/null || true

                mdadm --create "$RAID" \
                  --verbose \
                  --level=0 \
                  --raid-devices=3 \
                  --chunk=512 \
                  --metadata=1.2 \
                  --layout=original \
                  "$RAID_A" "$RAID_B" "$RAID_C"

                udevadm settle

                echo
                mdadm --detail "$RAID"
                echo

                # ---------------------------------------------------------
                # Root filesystem
                # ---------------------------------------------------------

                echo "[7/8] Formatting root filesystem..."

                mkfs.ext4 -L nixos "$RAID"

                # ---------------------------------------------------------
                # Mount
                # ---------------------------------------------------------

                echo "[8/8] Mounting installation..."

                mkdir -p "$TARGET"
                mount "$RAID" "$TARGET"

                mkdir -p "$TARGET/boot"
                mount "$EFI" "$TARGET/boot"

                echo
                echo "Installation target:"
                findmnt "$TARGET"
                findmnt "$TARGET/boot"
                echo

                # ---------------------------------------------------------
                # Generate hardware config
                # ---------------------------------------------------------

                echo "Generating hardware configuration..."

                nixos-generate-config --root "$TARGET"

                generated="$TARGET/etc/nixos/hardware-configuration.nix"

                if [[ ! -f "$generated" ]]; then
                  echo "ERROR: nixos-generate-config did not produce:"
                  echo "  $generated"
                  exit 1
                fi

                # Keep the freshly generated hardware configuration while
                # replacing the rest with our known-good configuration.
                cp "$generated" /tmp/hardware-configuration.nix

                rm -rf "$TARGET/etc/nixos"
                mkdir -p "$TARGET/etc/nixos"

                cp -a "$CONFIG"/. "$TARGET/etc/nixos/"

                cp \
                  /tmp/hardware-configuration.nix \
                  "$TARGET/etc/nixos/hardware-configuration.nix"

                echo
                echo "=============================================="
                echo "          INSTALLATION TARGET READY"
                echo "=============================================="
                echo
                echo "Configuration:"
                find "$TARGET/etc/nixos" -maxdepth 2 -type f -print
                echo
                echo "RAID:"
                mdadm --detail "$RAID"
                echo
                echo "Mounts:"
                findmnt "$TARGET"
                findmnt "$TARGET/boot"
                echo
                echo "Next:"
                echo
                echo "  nixos-install \\"
                echo "    --root $TARGET \\"
                echo "    --flake $TARGET/etc/nixos#raysha"
                echo
                echo "=============================================="
              '')
            ];

            boot.swraid.enable = true;

            environment.etc."raysha-readme".text = ''
              RAYSHA RECOVERY ISO

              Run:

                raysha-install

              The installer will identify the three raysha drives
              by their model names and refuse to continue unless
              exactly one of each is present.

              It will create:

                Samsung 970 EVO Plus 2TB
                  EFI
                  RAID0 member

                Samsung 860 EVO 1TB
                  RAID0 member

                Corsair Force MP600 1TB
                  RAID0 member

                md0
                  RAID0
                  512 KiB chunks
                  mdadm metadata 1.2

                ext4
                  /

              The current NixOS configuration is embedded in:

                /etc/raysha-config

              The generated hardware-configuration.nix is preserved
              and combined with that configuration.

              The final installation command is:

                nixos-install --root /mnt \
                  --flake /mnt/etc/nixos#raysha
            '';

            system.stateVersion = "25.05";
          }
        )
      ];
    };

    packages.x86_64-linux.iso =
      self.nixosConfigurations.rayshaRecovery.config.system.build.isoImage;
  };
}