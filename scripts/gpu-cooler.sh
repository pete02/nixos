    #!/usr/bin/env bash
set -euo pipefail

check() {
    echo "Checking nvidia-smi..."
    command -v nvidia-smi >/dev/null || return 1

    echo "Checking awk..."
    command -v awk >/dev/null || return 1
}

if [[ "${1:-}" == "--check" ]]; then
    check
    exit $?
fi

echo 1 > /sys/class/hwmon/hwmon1/pwm2_enable
echo 1 > /sys/class/hwmon/hwmon1/pwm5_enable

while true; do
    temp=$(/run/current-system/sw/bin/nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader)

    

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
    echo $speed > /sys/class/hwmon/hwmon1/pwm2
    echo $speed > /sys/class/hwmon/hwmon1/pwm5

    sleep 1
    done