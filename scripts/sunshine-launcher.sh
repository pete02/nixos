#!/usr/bin/env bash
set -euo pipefail


check() {
    echo "Checking jq..."
    command -v jq >/dev/null || return 1
    echo "Checking hyprctl..."
    command -v hyprctl >/dev/null || return 1
}

if [[ "${1:-}" == "--check" ]]; then
    check
    exit $?
fi


if (($# == 0)); then
    echo "Usage: sunshine-launcher <command> [args...]" >&2
    exit 1
fi

# Snapshot windows that already exist.
declare -A existing

while read -r address; do
    existing["$address"]=1
done < <(
    hyprctl clients -j |
        jq -r '.[].address'
)

# Launch the application.
"$@" &
child_pid=$!

# Wait for a new window to appear.
for _ in {1..100}; do
    while read -r address; do
        [[ -n "${existing[$address]:-}" ]] && continue

        hyprctl dispatch movetoworkspacesilent \
            "10,address:$address"

        wait "$child_pid"
        exit $?
    done < <(
        hyprctl clients -j |
            jq -r '.[].address'
    )

    sleep 0.1
done

echo "Warning: no new Hyprland window detected" >&2

wait "$child_pid"