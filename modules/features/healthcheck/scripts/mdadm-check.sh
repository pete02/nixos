
#!/usr/bin/env bash
# Storage health check: Linux MD RAID arrays, read from sysfs.
#
#   mdadm_check.sh --check        verify prerequisites and list arrays
#   mdadm_check.sh --test-notify  send a test notification
#   mdadm_check.sh --scrub        start an MD RAID check; needs root
#   mdadm_check.sh                inspect state and alert on problems
#
# Environment:
#   EXPECT    space-separated MD devices that MUST exist, e.g. "md127"
#   NTFY_URL  ntfy topic URL (empty disables alerts)
#   LOGFILE   result log (default /var/log/health-check/mdadm_check.log)
#   SYS       sysfs root (default /sys; override for testing)

set -u

SYS=${SYS:-/sys}
NTFY_URL=${NTFY_URL-https://ntfy.lumilukko.com/Raysha}
LOGFILE=${LOGFILE:-/var/log/health-check/mdadm_check.log}
EXPECT=${EXPECT:-}

CHECK_ONLY=0
TEST_NOTIFY=0
SCRUB=0

while (( $# )); do
    case $1 in
        --check)       CHECK_ONLY=1 ;;
        --test-notify) TEST_NOTIFY=1 ;;
        --scrub)       SCRUB=1 ;;
        -h|--help)     sed -n '2,/^$/p' "$0"; exit 0 ;;
        *)             echo "unknown argument: $1" >&2; exit 2 ;;
    esac
    shift
done

rd() {
    local v=""
    [[ -r $1 ]] && read -r v < "$1"
    printf '%s' "$v"
}

notify() {
    [[ -n $NTFY_URL ]] &&
        command -v curl >/dev/null 2>&1 &&
        curl -fsS -H "Title: $1" -H "Priority: high" \
            -d "$2" "$NTFY_URL" >/dev/null || true
}

md_devices() {
    local d
    for d in "$SYS"/block/md*; do
        [[ -d $d/md ]] && echo "${d##*/}"
    done
}

missing_expected() {
    local n
    for n in $EXPECT; do
        [[ -e $SYS/block/$n ]] || echo "$n"
    done
}

check_commands() {
    local verbose=$1 bad=0

    if [[ -n $NTFY_URL ]]; then
        if command -v curl >/dev/null 2>&1; then
            (( verbose )) && echo "  ok       command curl"
        else
            echo "  MISSING  command curl (needed for alerts)"
            bad=1
        fi
    elif (( verbose )); then
        echo "  note     NTFY_URL is empty: curl not required"
    fi

    return "$bad"
}

preflight() {
    local bad=0

    check_commands 0 || bad=1

    if [[ ! -d $SYS/block ]]; then
        echo "  MISSING  $SYS/block"
        bad=1
    fi

    return "$bad"
}

if (( TEST_NOTIFY )); then
    [[ -n $NTFY_URL ]] || {
        echo "NTFY_URL is empty; notifications are disabled" >&2
        exit 1
    }
    command -v curl >/dev/null 2>&1 || {
        echo "curl is not installed" >&2
        exit 1
    }

    code=$(curl -sS -o /dev/null -w '%{http_code}' \
        -H "Title: mdadm check TEST" \
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

if (( CHECK_ONLY )); then
    echo "Checking required commands:"
    if check_commands 1; then
        echo "All good."
        exit 0
    else
        echo "Check FAILED."
        exit 1
    fi
fi

if ! pf=$(preflight 0); then
    echo "Preflight FAILED, MD RAID check not run:"
    echo "$pf"
    notify "mdadm check could not run" "$pf"
    exit 1
fi

if (( SCRUB )); then
    (( EUID == 0 )) || {
        echo "--scrub needs root" >&2
        exit 1
    }

    rc=0

    while IFS= read -r name; do
        [[ -n $name ]] || continue

        md=$SYS/block/$name/md
        level=$(rd "$md/level")
        action=$(rd "$md/sync_action")

        case $level in
            raid1|raid4|raid5|raid6|raid10) ;;
            *)
                echo "skip $name ($level: nothing to scrub)"
                continue
                ;;
        esac

        if [[ $action != idle ]]; then
            echo "skip $name (sync_action=$action)"
            continue
        fi

        if echo check > "$md/sync_action"; then
            echo "scrub started on $name; result is read by the next normal run (mismatch_cnt)"
        else
            echo "could not start scrub on $name" >&2
            rc=1
        fi
    done < <(md_devices)

    exit "$rc"
fi

problems=()
status=()

check_md() {
    local name md level state action degraded mm dev ds

    while IFS= read -r name; do
        [[ -n $name ]] || continue

        md=$SYS/block/$name/md
        level=$(rd "$md/level")
        state=$(rd "$md/array_state")
        action=$(rd "$md/sync_action")

        status+=(
            "md: $name level=${level:-?} state=${state:-?} sync=${action:-n/a}"
        )

        [[ $state == inactive ]] &&
            problems+=("md: $name ($level) is inactive")

        degraded=$(rd "$md/degraded")
        if [[ -n $degraded && $degraded != 0 ]]; then
            problems+=(
                "md: $name ($level) is DEGRADED, $degraded device(s) missing or failed"
            )
        fi

        for dev in "$md"/dev-*; do
            [[ -d $dev ]] || continue
            ds=$(rd "$dev/state")

            [[ $ds == *faulty* ]] &&
                problems+=("md: $name member ${dev##*/dev-} is faulty ($ds)")
        done

        mm=$(rd "$md/mismatch_cnt")
        if [[ -n $mm && $mm != 0 ]]; then
            problems+=(
                "md: $name mismatch_cnt=$mm after the last scrub (possible silent corruption)"
            )
        fi
    done < <(md_devices)
}

while IFS= read -r n; do
    [[ -n $n ]] || continue
    problems+=("expected device $n is missing")
done < <(missing_expected)

check_md

report() {
    date

    if (( ${#status[@]} )); then
        printf '%s\n' "${status[@]}"
    else
        echo "no MD RAID arrays found"
    fi

    if (( ${#problems[@]} )); then
        printf 'ALERT: %s\n' "${problems[@]}"
    else
        echo "OK: no issues"
    fi
}

report

if mkdir -p "$(dirname "$LOGFILE")" 2>/dev/null; then
    report >> "$LOGFILE" 2>/dev/null ||
        echo "warning: could not write $LOGFILE" >&2
fi

if (( ${#problems[@]} )); then
    notify "mdadm check FAILED" "$(printf '%s\n' "${problems[@]}")"
    exit 1
fi
