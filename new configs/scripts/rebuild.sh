cd /etc/nixos
set -euo pipefail
HOSTNAME=$(hostname)
UNSTABLE_BRANCH="rebuild-unstable/$HOSTNAME"
nix flake check

if ! treefmt --no-cache --tree-root /etc/nixos &>/dev/null; then
    echo "treefmt failed, running for output:"
    treefmt --no-cache --tree-root  /etc/nixos
    exit 1
fi
git add /etc/nixos/.

# Shows your changes
git diff -U0 '*.nix'

git commit -am "Rebuild on $HOSTNAME: $(date '+%Y-%m-%d %H:%M:%S')" || echo "No changes to commit."
echo "Rebuilding system for $HOSTNAME..."
echo "Please insert password for nixos-rebuild"
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

if sudo nixos-rebuild switch --flake "/etc/nixos#$HOSTNAME" --impure; then
    echo "Rebuild successful"

    nvd diff $(ls -d1v /nix/var/nix/profiles/system-*-link|tail -n 2) > /etc/nixos/diff.txt
    cat /etc/nixos/diff.txt
    git add /etc/nixos/diff.txt

    if [[ "$CURRENT_BRANCH" == "$UNSTABLE_BRANCH" ]]; then
        git commit --amend --no-edit
        git push origin "$UNSTABLE_BRANCH"
        git checkout master
        git pull --rebase origin master
        git merge --no-ff "$UNSTABLE_BRANCH" -m "Merge successful rebuild from $UNSTABLE_BRANCH"
        git push origin master
        git push origin --delete "$UNSTABLE_BRANCH"
    else
        git commit --amend --no-edit
        git pull --rebase origin master
        git push origin master
    fi
else
    echo "Rebuild failed, not pushing."
    if [ "$CURRENT_BRANCH" = "$UNSTABLE_BRANCH" ]; then
        # We're already working on a fix — just rebase and push
        git pull --rebase origin "$UNSTABLE_BRANCH"
    else
        # Stale unstable branch from a previous failure — nuke and recreate from current
        git push origin --delete "$UNSTABLE_BRANCH" 2>/dev/null || true
        git branch -D "$UNSTABLE_BRANCH" 2>/dev/null || true
        git checkout -b "$UNSTABLE_BRANCH"
    fi
    git commit -am "Rebuild failed on $HOSTNAME: $(date '+%Y-%m-%d %H:%M:%S')" || echo "No changes to commit."
    git push -u origin "$UNSTABLE_BRANCH"

    exit 1
fi