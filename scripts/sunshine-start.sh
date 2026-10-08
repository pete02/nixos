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

pkill -f '\.hyprpanel-wrapped' || true
hyprctl keyword monitor DP-2,disable
hyprctl keyword monitor DP-1,disable

sleep 0.5