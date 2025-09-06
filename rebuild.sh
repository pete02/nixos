#!/usr/bin/env bash
set -euo pipefail
HOSTNAME=$(hostname)

treefmt . &>/dev/null  || ( mixfmt . ; echo "formatting failed!" && exit 1)

git add /etc/nixos/.

# Shows your changes
git diff -U0 '*.nix'

git commit -am "Rebuild on $HOSTNAME: $(date '+%Y-%m-%d %H:%M:%S')" || echo "No changes to commit."


echo "Rebuilding system for $HOSTNAME..."
if sudo nixos-rebuild switch --flake "/etc/nixos#$HOSTNAME"; then
    echo "Rebuild successful, pushing changes..."
    git push
else
    echo "Rebuild failed, not pushing."
    exit 1
fi