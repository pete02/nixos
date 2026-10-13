#!/usr/bin/env bash
# Health check: SMART self-test on every listed disk + memtester on RAM.
#
#   health_check.sh --check            only verify that required commands/devices exist
#   health_check.sh                    full run, devices from $DEVICES
#   health_check.sh -d /dev/sda -d /dev/sdb -m 200M -i 3
#
# Environment (all optional):
#   DEVICES    space-separated disk list      (default: /dev/sda)
#   MEMSIZE    memtester size                 (default: 100M)
#   ITERATIONS memtester loops                (default: 5)
#   LOGFILE    append-only result log         (default: /var/log/health-check/health_check.log)
#   NTFY_URL   ntfy topic URL for alerts      (default: none)
#   SMART_WAIT_MAX  max seconds to wait for SMART tests (default: 600)

set -u

MEMSIZE=${MEMSIZE:-100M}
ITERATIONS=${ITERATIONS:-5}
DEVICES=${DEVICES:-/dev/sda}
LOGFILE=${LOGFILE:-/var/log/health-check/health_check.log}
NTFY_URL=${NTFY_URL:-https://ntfy.lumilukko.com/Server}
SMART_WAIT_MAX=${SMART_WAIT_MAX:-600}

# ---------------------------------------------------------------- arguments
CHECK_ONLY=0
TEST_NOTIFY=0  
cli_devs=()
while (( $# )); do
    case $1 in
        --check)        CHECK_ONLY=1 ;;
        --test-notify)  TEST_NOTIFY=1 ;;
        -d|--device)    shift; cli_devs+=("${1:?missing value for --device}") ;;
        -m|--memsize)   shift; MEMSIZE=${1:?missing value for --memsize} ;;
        -i|--iterations) shift; ITERATIONS=${1:?missing value for --iterations} ;;
        -h|--help)      sed -n '2,15p' "$0"; exit 0 ;;
        *)              echo "unknown argument: $1" >&2; exit 2 ;;
    esac
    shift
done

read -r -a devs <<< "$DEVICES"
(( ${#cli_devs[@]} )) && devs=("${cli_devs[@]}")

# ---------------------------------------------------------------- helpers
notify() {  # notify <title> <message>
    [[ -n $NTFY_URL ]] && command -v curl >/dev/null 2>&1 &&
        curl -fsS -H "Title: $1" -H "Priority: high" -d "$2" "$NTFY_URL" >/dev/null || true
}

# preflight <verbose 0|1>: returns 1 if anything required is missing
preflight() {
    local verbose=$1 bad=0 cmd dev
    local cmds=(smartctl memtester grep seq sleep date curl)
    [[ -n $NTFY_URL ]] && cmds+=(curl)

    for cmd in "${cmds[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            (( verbose )) && echo "  ok       command $cmd"
        else
            echo "  MISSING  command $cmd"; bad=1
        fi
    done

    if (( ${#devs[@]} == 0 )); then
        echo "  MISSING  no devices configured"; bad=1
    fi
    
    return $bad
}

# ---------------------------------------------------------------- preflight
if (( CHECK_ONLY )); then
    echo "Preflight check:"
    if preflight 1; then echo "All good."; exit 0; else echo "Preflight FAILED."; exit 1; fi
fi

if (( TEST_NOTIFY )); then
    [[ -n $NTFY_URL ]] || { echo "NTFY_URL is not set" >&2; exit 1; }
    code=$(curl -sS -o /dev/null -w '%{http_code}' \
        -H "Title: servu health check TEST" -H "Priority: high" \
        -d "Test notification from $HOSTNAME" "$NTFY_URL") \
        || { echo "curl failed (network/DNS/TLS)" >&2; exit 1; }
    echo "ntfy responded HTTP $code"
    [[ $code == 2* ]]
    exit
fi

if ! pf=$(preflight 0); then
    echo "Preflight FAILED, health check not run:"
    echo "$pf"
    notify "servu health check could not run" "$pf"
    exit 1
fi

# ---------------------------------------------------------------- full run
problems=()

# Start SMART short tests on all disks (they run inside the drives, in parallel)
for dev in "${devs[@]}"; do
    smartctl -t short "$dev" >/dev/null 2>&1 ||
        problems+=("Disk $dev: could not start SMART self-test")
done

# RAM test overlaps with the disk tests
memtester "$MEMSIZE" "$ITERATIONS" >/dev/null 2>&1
ram_rc=$?
if (( ram_rc != 0 )); then
    errs=()
    (( ram_rc & 1 )) && errs+=("allocation/locking error")
    (( ram_rc & 2 )) && errs+=("stuck address error")
    (( ram_rc & 4 )) && errs+=("other test error")
    (( ${#errs[@]} )) || errs+=("exit code $ram_rc")
    problems+=("RAM: $(IFS=,; echo "${errs[*]}")")
fi

# Wait for each SMART test to finish, then read the results
deadline=$(( SECONDS + SMART_WAIT_MAX ))
for dev in "${devs[@]}"; do
    while smartctl -c "$dev" | grep -q "Self-test routine in progress" &&
          (( SECONDS < deadline )); do
        sleep 10
    done

    line=$(smartctl -l selftest "$dev" | grep -m1 '^# 1')
    if [[ -z $line ]]; then
        problems+=("Disk $dev: no SMART self-test result found")
    elif [[ $line != *"Completed without error"* ]]; then
        problems+=("Disk $dev: self-test did not complete cleanly: $line")
    fi

    smartctl -H "$dev" | grep -q "PASSED" ||
        problems+=("Disk $dev: overall SMART health is not PASSED")
done

# ---------------------------------------------------------------- report
report() {
    date
    echo "Devices: ${devs[*]}"
    if (( ${#problems[@]} )); then
        printf 'ALERT: %s\n' "${problems[@]}"
    else
        echo "OK: RAM and ${#devs[@]} disk(s), no issues"
    fi
}

report                                  # stdout -> journald when run by systemd

if mkdir -p "$(dirname "$LOGFILE")" 2>/dev/null; then
    report >> "$LOGFILE" 2>/dev/null || echo "warning: could not write $LOGFILE" >&2
fi

if (( ${#problems[@]} )); then
    notify "servu health check FAILED" "$(printf '%s\n' "${problems[@]}")"
    exit 1
fi