set -euo pipefail
HOSTNAME=$(hostname)
UNSTABLE_BRANCH="rebuild-unstable/$HOSTNAME"
CONFIG_FOLDER=/etc/nixos



check_host_isolation() {
    local host_root="modules/hosts"
    local failed=0

    mapfile -t hosts < <(
        find "$host_root" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort
    )

    for host in "${hosts[@]}"; do
        for other in "${hosts[@]}"; do
            [[ "$host" == "$other" ]] && continue

            if grep -RInFw "$other" "$host_root/$host" >/dev/null; then
                echo "❌ '$other' referenced inside $host_root/$host"
                grep -RInFw "$other" "$host_root/$host"
                failed=1
            fi
        done
    done

    (( failed == 0 ))
}


validate_config() {
    echo "Checking host isolation..."
    check_host_isolation

    echo "Running flake checks..."
    nix flake check $CONFIG_FOLDER
    if ! treefmt --no-cache --tree-root "$CONFIG_FOLDER" &>/dev/null; then
        echo "treefmt failed:"
        treefmt --no-cache --tree-root "$CONFIG_FOLDER"
        return 1
    fi
}


handle_success(){
    echo "Rebuild successful"

    nvd diff $(ls -d1v /nix/var/nix/profiles/system-*-link|tail -n 2) > $CONFIG_FOLDER/diff.txt
    cat "$CONFIG_FOLDER/diff.txt"
    git add "$CONFIG_FOLDER/diff.txt"

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
}

rebuild_function(){
    sudo nixos-rebuild switch --flake "$CONFIG_FOLDER#$HOSTNAME" --impure
}

handle_failure(){
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
}


cd $CONFIG_FOLDER
validate_config
git add "$CONFIG_FOLDER/."

# Shows your changes
git diff -U0 '*.nix'

git commit -am "Rebuild on $HOSTNAME: $(date '+%Y-%m-%d %H:%M:%S')" || echo "No changes to commit."
echo "Rebuilding system for $HOSTNAME..."
echo "Please insert password for nixos-rebuild"
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

if rebuild_function; then
    handle_success
else
    handle_failure
    exit 1
fi