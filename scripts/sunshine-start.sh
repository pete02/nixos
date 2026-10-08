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


hyprctl keyword monitor DP-2,disable
hyprctl keyword monitor DP-1,disable
hyprctl keyword monitor HDMI-A-1,3840x2160@59.97,auto,1 
hyprctl dispatch moveworkspacetomonitor 10 HDMI-A-1