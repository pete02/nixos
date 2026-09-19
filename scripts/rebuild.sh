set -euo pipefail

check() {
    check_command() {
        local name="$1"

        echo "Checking ${name}..."
        if ! command -v "$name" >/dev/null; then
            echo "ERROR: ${name} not found in PATH"
            return 1
        fi
    }

    check_command git || return 1
    check_command nixos-rebuild || return 1
    check_command treefmt || return 1
    check_command stat || return 1
    check_command sudo || return 1
    check_command find || return 1
    check_command sort || return 1
    check_command grep || return 1
    check_command hostname || return 1
    check_command nvd || return 1
    check_command date || return 1

    echo "All checks passed."
}

if [[ "${1:-}" == "--check" ]]; then
    check()
    exit $?
fi

HOSTNAME=$(hostname)
UNSTABLE_BRANCH="rebuild-unstable/$HOSTNAME"
CONFIG_FOLDER=/etc/nixos
GIT_USER=$(stat -c '%U' "$CONFIG_FOLDER/.git")

git_cmd() {
    if [[ $EUID -eq 0 ]]; then
        sudo -H -u "$GIT_USER" git "$@"
    else
        git "$@"
    fi
}


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
    nix flake check "$CONFIG_FOLDER"
    if ! treefmt --no-cache --tree-root "$CONFIG_FOLDER" &>/dev/null; then
        echo "treefmt failed:"
        treefmt --no-cache --tree-root "$CONFIG_FOLDER"
        return 1
    fi
}


handle_success(){
    echo "Rebuild successful"

    mapfile -t system_links < <(
    find /nix/var/nix/profiles \
        -maxdepth 1 \
        -type l \
        -name 'system-*-link' \
        -printf '%p\n' |
        sort -V
    )

    nvd diff \
        "${system_links[-2]}" \
        "${system_links[-1]}" \
        > "${CONFIG_FOLDER}/${HOSTNAME}-diff.txt"


    cat "$CONFIG_FOLDER/$HOSTNAME-diff.txt"
    git_cmd add "$CONFIG_FOLDER/$HOSTNAME-diff.txt"

    if [[ "$CURRENT_BRANCH" == "$UNSTABLE_BRANCH" ]]; then
        git_cmd commit --amend --no-edit
        git_cmd push origin "$UNSTABLE_BRANCH"
        git_cmd checkout master
        git_cmd pull --rebase origin master
        git_cmd merge --no-ff "$UNSTABLE_BRANCH" -m "Merge successful rebuild from $UNSTABLE_BRANCH"
        git_cmd push origin master
        git_cmd push origin --delete "$UNSTABLE_BRANCH"
    else
        git_cmd commit --amend --no-edit
        git_cmd pull --rebase origin master
        git_cmd push origin master
    fi
}

rebuild_function() {
    if [[ $EUID -eq 0 ]]; then
        nixos-rebuild switch --flake "$CONFIG_FOLDER#$HOSTNAME" --impure
    else
        sudo nixos-rebuild switch --flake "$CONFIG_FOLDER#$HOSTNAME" --impure
    fi
}

handle_failure(){
    echo "Rebuild failed, not pushing."
    if [ "$CURRENT_BRANCH" = "$UNSTABLE_BRANCH" ]; then
        # We're already working on a fix — just rebase and push
        git_cmd pull --rebase origin "$UNSTABLE_BRANCH"
    else
        # Stale unstable branch from a previous failure — nuke and recreate from current
        git_cmd push origin --delete "$UNSTABLE_BRANCH" 2>/dev/null || true
        git_cmd branch -D "$UNSTABLE_BRANCH" 2>/dev/null || true
        git_cmd checkout -b "$UNSTABLE_BRANCH"
    fi
    git_cmd commit -am "Rebuild failed on $HOSTNAME: $(date '+%Y-%m-%d %H:%M:%S')" || echo "No changes to commit."
    git_cmd push -u origin "$UNSTABLE_BRANCH"
}


cd "$CONFIG_FOLDER"
validate_config
git_cmd add "$CONFIG_FOLDER/."

# Shows your changes
git_cmd diff -U0 '*.nix'

git_cmd commit -am "Rebuild on $HOSTNAME: $(date '+%Y-%m-%d %H:%M:%S')" || echo "No changes to commit."
echo "Rebuilding system for $HOSTNAME..."
echo "Please insert password for nixos-rebuild"
CURRENT_BRANCH=$(git_cmd rev-parse --abbrev-ref HEAD)

if rebuild_function; then
    handle_success
else
    handle_failure
    exit 1
fi