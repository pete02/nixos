#!/usr/bin/env bash

set -euo pipefail

rpcs3 --no-gui "/home/pete/ps3_isos/LEGO Indiana Jones 2 - The Adventure Continues (Europe) (En,Fr,De,Es,It,Da).iso" &
pid=$!

for _ in {1..50}; do
    if hyprctl clients | grep -q "pid: $pid"; then
        break
    fi
    sleep 0.1
done

hyprctl dispatch focuswindow "pid:$pid"
hyprctl dispatch fullscreen
wait "$pid"