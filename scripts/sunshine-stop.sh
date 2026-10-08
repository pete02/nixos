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


hyprctl keyword monitor HDMI-A-1,disable

hyprctl keyword monitor DP-2,3440x1440@164.90,auto,1

hyprctl keyword monitor DP-1,2560x1440@120,auto,1