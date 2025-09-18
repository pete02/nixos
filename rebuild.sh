#!/usr/bin/env bash
set -euo pipefail
HOSTNAME=$(hostname)

if ! treefmt /etc/nixos/. &>/dev/null; then
    echo "treefmt failed, running for output:"
    treefmt /etc/nixos/.
    exit 1
fi
git add /etc/nixos/.

# Shows your changes
git diff -U0 '*.nix'

git commit -am "Rebuild on $HOSTNAME: $(date '+%Y-%m-%d %H:%M:%S')" || echo "No changes to commit."


echo "Rebuilding system for $HOSTNAME..."
if sudo nixos-rebuild switch --flake "/etc/nixos#$HOSTNAME"; then
    echo "Rebuild successful"
    git push
else
    echo "Rebuild failed, not pushing."
    exit 1
fi




