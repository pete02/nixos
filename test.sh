cd /etc/nixos
changed=0

nix flake update
if ! git diff --quiet flake.lock; then
  changed=1
fi