# nixos-installer flake

| Target   | What you get                                     | How it gets onto a drive            |
|----------|--------------------------------------------------|-------------------------------------|
| iso-x86  | Live installer ISO (UEFI x86_64)                 | `flash iso-x86 /dev/sdX`, boot it, then `install` |
| x86      | The system the ISO installs (`hosts/x86`)        | `sudo nixos-installer install /dev/nvme0n1` |
| rpi3     | Full-system SD image (aarch64, 1 GB RAM tuned)   | `flash rpi3 /dev/mmcblk0`           |
| rpi5     | Full-system SD image (nixos-raspberrypi)         | `flash rpi5 /dev/mmcblk0`           |

## Use
1. Edit `settings.nix` (SSH keys, username, password, timezone).
2. `git add -A` (flakes in a git repo only see tracked files).
3. `nix run .# -- list`
   - `nix run .# -- build rpi5`
   - `nix run .# -- flash iso-x86 /dev/sdb`
4. Booted the ISO on the target machine: `sudo nixos-installer install /dev/nvme0n1`
   (needs network: flake inputs are fetched at install time).

Building rpi images on x86 needs `boot.binfmt.emulatedSystems = [ "aarch64-linux" ];`
on the build machine (or a remote aarch64 builder).

Add more machines by creating `hosts/<name>/default.nix` and a `nixosConfigurations.<name>`.
