#!/usr/bin/env bash

set -euo pipefail

if [[ "${1:-}" == "--check" ]]; then
    exit 0
fi

ISO="@HOME@/ps3_isos/LEGO Indiana Jones 2 - The Adventure Continues (Europe) (En,Fr,De,Es,It,Da).iso"

rpcs3 --no-gui "$ISO" &
pid=$!

for _ in {1..50}; do
    if hyprctl clients | grep -q "pid: $pid"; then
        break
    fi
    sleep 0.1
done

hyprctl dispatch focuswindow "pid:$pid"
hyprctl dispatch fullscreenstate 2 2
wait "$pid"