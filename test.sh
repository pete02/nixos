time (
  set -e
  TARGET='pete@192.168.88.100'
  FLAKE='#rpi3-test'

  sudo nix build ".#nixosConfigurations.rpi3-test.config.system.build.toplevel" \
    --out-link result-rpi

  sudo nix copy --to "ssh-ng://${TARGET}" ./result-rpi

  ssh "$TARGET" \
    "sudo nixos-rebuild switch --flake /etc/nixos${FLAKE}"
)