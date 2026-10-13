
#!/usr/bin/env bash
# Health check: SMART self-tests on configured disks + memtester on RAM.
#
#   healthcheck.sh --check
#       Package validation only; safe during a Nix build.
#   healthcheck.sh --test-notify
#       Send a test notification and report the HTTP status.
#   healthcheck.sh
#       Runtime preflight, then inspect disk and RAM health.
#   healthcheck.sh -d /dev/sda -d /dev/sdb -m 200M -i 3
#
# Environment:
#   DEVICES        space-separated disk list (default: /dev/sda)
#   MEMSIZE        memtester size (default: 100M)
#   ITERATIONS     memtester loops (default: 5)
#   LOGFILE        append-only log (default: /var/log/health-check/health_check.log)
#   NTFY_URL       ntfy topic URL for alerts (default: none)
#   SMART_WAIT_MAX maximum seconds to wait for SMART tests (default: 600)

set -u

MEMSIZE=${MEMSIZE:-100M}
ITERATIONS=${ITERATIONS:-5}
DEVICES=${DEVICES:-/dev/sda}
LOGFILE=${LOGFILE:-/var/log/health-check/health_check.log}
NTFY_URL=${NTFY_URL:-https://ntfy.lumilukko.com/Aria}
SMART_WAIT_MAX=${SMART_WAIT_MAX:-600}

# ---------------------------------------------------------------- arguments

CHECK_ONLY=0
TEST_NOTIFY=0
cli_devs=()

while (( $# )); do
    case $1 in
        --check)
            CHECK_ONLY=1
            ;;
        --test-notify)
            TEST_NOTIFY=1
            ;;
        -d|--device)
            shift
            cli_devs+=("${1:?missing value for --device}")
            ;;
        -m|--memsize)
            shift
            MEMSIZE=${1:?missing value for --memsize}
            ;;
        -i|--iterations)
            shift
            ITERATIONS=${1:?missing value for --iterations}
            ;;
        -h|--help)
            sed -n '2,15p' "$0"
            exit 0
            ;;
        *)
            echo "unknown argument: $1" >&2
            exit 2
            ;;
    esac
    shift
done

read -r -a devs <<< "$DEVICES"
if (( ${#cli_devs[@]} )); then
    devs=("${cli_devs[@]}")
fi

# ---------------------------------------------------------------- helpers

notify() {
    # notify <title> <message>
    [[ -n $NTFY_URL ]] &&
        command -v curl >/dev/null 2>&1 &&
        curl -fsS -H "Title: $1" -H "Priority: high" \
            -d "$2" "$NTFY_URL" >/dev/null || true
}

# ---------------------------------------------------------------- package validation
# Must not inspect real disks, access hardware, run tests, or notify.
# This is the phase invoked by mkScript during the Nix build.

package_check() {
    local bad=0 cmd
    local -a cmds=(smartctl memtester grep sleep date)

    if [[ -n $NTFY_URL ]]; then
        cmds+=(curl)
    fi

    for cmd in "${cmds[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            echo "  ok       command $cmd"
        else
            echo "  MISSING  command $cmd"
            bad=1
        fi
    done

    if (( ${#devs[@]} == 0 )); then
        echo "  MISSING  no devices configured"
        bad=1
    fi

    if [[ ! $ITERATIONS =~ ^[1-9][0-9]*$ ]]; then
        echo "  INVALID  ITERATIONS must be a positive integer"
        bad=1
    fi

    if [[ ! $SMART_WAIT_MAX =~ ^[0-9]+$ ]]; then
        echo "  INVALID  SMART_WAIT_MAX must be a non-negative integer"
        bad=1
    fi

    if (( bad )); then
        return 1
    fi
    return 0
}

if (( CHECK_ONLY )); then
    echo "Package validation:"
    if package_check; then
        echo "Package validation PASSED."
        exit 0
    else
        echo "Package validation FAILED."
        exit 1
    fi
fi

# ---------------------------------------------------------------- test notification
# Intentionally independent of disk preflight and health inspection.

if (( TEST_NOTIFY )); then
    [[ -n $NTFY_URL ]] || {
        echo "NTFY_URL is empty; notifications are disabled" >&2
        exit 1
    }

    command -v curl >/dev/null 2>&1 || {
        echo "curl is not installed" >&2
        exit 1
    }

    command -v log >/dev/null 2>&1 || {
        echo "curl is not installed" >&2
        exit 1
    }

    code=$(curl -sS -o /dev/null -w '%{http_code}' \
        -H "Title: servu health check TEST" \
        -H "Priority: high" \
        -d "Test notification from ${HOSTNAME:-$(hostname)}" \
        "$NTFY_URL") || {
        echo "curl failed (network/DNS/TLS)" >&2
        exit 1
    }

    echo "ntfy responded HTTP $code"
    [[ $code == 2* ]]
    exit
fi

# ---------------------------------------------------------------- runtime preflight
# Host-dependent checks. Failures must notify and prevent inspection.

runtime_preflight() {
    local bad=0 dev

    if ! package_check >/dev/null 2>&1; then
        echo "Required commands or configuration are invalid"
        bad=1
    fi

    for dev in "${devs[@]}"; do
        if [[ ! -b $dev ]]; then
            echo "Disk $dev does not exist or is not a block device"
            bad=1
        elif [[ ! -r $dev ]]; then
            echo "Disk $dev is not readable by this service"
            bad=1
        fi
    done

    return "$bad"
}

if ! pf=$(runtime_preflight); then
    echo "Runtime preflight FAILED, health check not run:"
    echo "$pf"
    notify "servu health check could not run" "$pf"
    exit 1
fi

# ---------------------------------------------------------------- health inspection

problems=()

# Start SMART short tests on all disks (they run inside the drives, in parallel).
for dev in "${devs[@]}"; do
    smartctl -t short "$dev" >/dev/null 2>&1 ||
        problems+=("Disk $dev: could not start SMART self-test")
done

# RAM test overlaps with the disk tests.
if memtester "$MEMSIZE" "$ITERATIONS" >/dev/null 2>&1; then
    ram_rc=0
else
    ram_rc=$?
fi

if (( ram_rc != 0 )); then
    errs=()
    (( ram_rc & 1 )) && errs+=("allocation/locking error")
    (( ram_rc & 2 )) && errs+=("stuck address error")
    (( ram_rc & 4 )) && errs+=("other test error")
    (( ${#errs[@]} )) || errs+=("exit code $ram_rc")
    problems+=("RAM: $(IFS=,; echo "${errs[*]}")")
fi

# Wait for each SMART test to finish, then read the results.
deadline=$(( SECONDS + SMART_WAIT_MAX ))


for dev in "${devs[@]}"; do
    while smartctl -c "$dev" 2>&1 | grep -q "Self-test routine in progress" &&
          (( SECONDS < deadline )); do
        sleep 10
    done

    log_output=$(smartctl -l selftest "$dev" 2>&1 || true)

    # ATA logs use entries such as "# 1 ..."; NVMe logs use
    # numbered rows such as " 0   Short ...".
    line=$(
        grep -m1 -E '^# *1[[:space:]]|^[[:space:]]*0[[:space:]]+Short[[:space:]]' \
            <<< "$log_output" || true
    )

    if [[ -z $line ]]; then
        problems+=("Disk $dev: no SMART self-test result found")
    elif [[ $line != *"Completed without error"* ]]; then
        problems+=("Disk $dev: self-test did not complete cleanly: $line")
    fi

    health_output=$(smartctl -H "$dev" 2>&1 || true)

    if grep -qE '^SMART overall-health self-assessment test result: PASSED$' \
        <<< "$health_output"; then
        if grep -q 'marginal Attributes' <<< "$health_output"; then
            log "WARNING: Disk $dev: SMART passed, but reports marginal attributes"
        fi
    else
        problems+=("Disk $dev: overall SMART health is not PASSED")
    fi
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

report

if mkdir -p "$(dirname "$LOGFILE")" 2>/dev/null; then
    report >> "$LOGFILE" 2>/dev/null ||
        echo "warning: could not write $LOGFILE" >&2
fi

if (( ${#problems[@]} )); then
    notify "servu health check FAILED" "$(printf '%s\n' "${problems[@]}")"
    exit 1
fi
