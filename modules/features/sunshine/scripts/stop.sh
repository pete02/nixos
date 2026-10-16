#!/usr/bin/env bash

set -euo pipefail


check() {

    echo "Checking hyprctl..."

    command -v hyprctl >/dev/null || return 1

}

if [[ "${1:-}" == "--check" ]]; then
    check
    exit $?

fi

hyprctl keyword monitor HDMI-A-1,3840x2160@30,7000x0,1
hyprctl keyword monitor DP-2,3440x1440@164.90,0x0,1,bitdepth,10
hyprctl keyword monitor DP-1,2560x1440@120,3440x0,1
hyprctl dispatch workspace 1
hyprpanel &
