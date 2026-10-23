#!/usr/bin/env bash
set -euo pipefail

check() {
    local missing=0 cmd
    local required=(nvidia-smi awk)

    for cmd in "${required[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo "bitwarden-backup: missing required command: $cmd" >&2
            missing=1
        fi
    done

    # Notifications are best-effort; curl is not required for the backup itself.
    return "$missing"
}


if [[ "${1:-}" == "--check" ]]; then
    check
    exit $?
fi

echo 1 > /sys/class/hwmon/hwmon1/pwm2_enable
echo 1 > /sys/class/hwmon/hwmon1/pwm5_enable

while true; do
    temp=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader)

    # Clamp temperature to 40–80°C
    if [ "$temp" -lt 40 ]; then temp=40; fi
    if [ "$temp" -gt 80 ]; then temp=80; fi

    # Scale to 0–255 PWM
    if [ "$temp" -le 55 ]; then
        speed=40      # very quiet fixed speed
    else
        speed=255
    fi
    # TODO: write PWM to correct hwmon path
    echo "$speed" > /sys/class/hwmon/hwmon1/pwm2
    echo "$speed" > /sys/class/hwmon/hwmon1/pwm5

    sleep 1
    done