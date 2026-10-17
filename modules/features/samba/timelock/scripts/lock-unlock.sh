#!/usr/bin/env bash
# =============================================================================
# Lock/Unlock utility (file-based, no background processes)
# =============================================================================
# Cycle:
#   unlock (user action) -> session timer starts (SESSION_SECS)
#   timer runs out       -> lock applied, lasts COOLDOWN_SECS (72h)
#   after 72h            -> state is "ready": nothing unlocks automatically,
#                           the user must run `unlock` again
#   unlock is refused from CUTOFF_HOUR until UNBLOCK_HOUR (e.g. 21:00-06:00)
#
# Everything is stored as timestamp files in STATE_DIR:
#   session_end : epoch when the active session ends (exists only while unlocked)
#   locked_at   : epoch when the lock was applied
#
# Because there is no daemon, the timer is enforced whenever `check` runs.
# Call `check` from your own code before granting access, and/or run it
# periodically (cron: * * * * * /path/lock-unlock-v2.sh check >/dev/null).
#
# Usage:  ./lock-unlock-v2.sh {unlock|check|status|lock}
#   or:   source lock-unlock-v2.sh; check; unlock; lock
#
# check exit codes:
#   0 = unlocked, session active (access granted)
#   1 = lock period over, you CAN unlock now
#   2 = locked (cooldown running)
#   3 = lock period over, but unlock is blocked by the time of day
#   4 = state directory problem
# =============================================================================

# Configuration (override with environment variables)
if [[ "$(id -u)" -eq 0 ]]; then
    STATE_DIR="${STATE_DIR:-/var/lib/lock-unlock}"
else
    STATE_DIR="${STATE_DIR:-$HOME/.lock-unlock}"
fi
SESSION_SECS="${SESSION_SECS:-3600}"        # active timer length (default 1 h)
COOLDOWN_SECS="${COOLDOWN_SECS:-259200}"    # lock length (default 72 h)
CUTOFF_HOUR="${CUTOFF_HOUR:-21}"            # no unlocking from this hour...
UNBLOCK_HOUR="${UNBLOCK_HOUR:-6}"           # ...until this hour

LOCK_FILE="${STATE_DIR}/locked_at"
SESSION_FILE="${STATE_DIR}/session_end"

# ------------------------------- helpers ------------------------------------

log() {
    if command -v logger >/dev/null 2>&1; then
        logger -t "lock-unlock" -- "$*" 2>/dev/null || echo "lock-unlock: $*" >&2
    else
        echo "lock-unlock: $*" >&2
    fi
}

now()    { date +%s; }
fmt_ts() { date -d "@$1" '+%Y-%m-%d %H:%M:%S'; }

fmt_dur() {
    local s=$1
    printf '%dh %02dm %02ds' $((s / 3600)) $(((s % 3600) / 60)) $((s % 60))
}

ensure_state_dir() {
    mkdir -p "${STATE_DIR}" 2>/dev/null || {
        echo "Cannot create state dir ${STATE_DIR} (run as root or set STATE_DIR)" >&2
        return 1
    }
}

read_ts()  { cat "$1" 2>/dev/null || echo 0; }
write_ts() { echo "$2" > "$1"; chmod 644 "$1"; }

# ------------------------- 1) the active timer ------------------------------

start_timer() {
    write_ts "${SESSION_FILE}" $(( $(now) + SESSION_SECS ))
}

# If a session exists and its time is up, apply the lock. The lock is dated at
# the moment the timer ran out, even if we only notice later.
expire_session_if_due() {
    [[ -f "${SESSION_FILE}" ]] || return 0
    local end
    end=$(read_ts "${SESSION_FILE}")
    if (( $(now) >= end )); then
        lock "${end}"
    fi
}

# --------------------------- 2) the 72h lock --------------------------------

# Seconds of lock left (0 if no lock or already over).
cooldown_remaining() {
    [[ -f "${LOCK_FILE}" ]] || { echo 0; return 0; }
    local r=$(( $(read_ts "${LOCK_FILE}") + COOLDOWN_SECS - $(now) ))
    (( r > 0 )) && echo "${r}" || echo 0
}

# lock [epoch]  - apply the lock now (or dated at the given epoch).
lock() {
    ensure_state_dir || return 4
    local at="${1:-$(now)}"

    # Don't restart a lock that is already running.
    if [[ -z "${1:-}" ]] && (( $(cooldown_remaining) > 0 )); then
        echo "Already locked until $(fmt_ts $(( $(read_ts "${LOCK_FILE}") + COOLDOWN_SECS )))."
        return 0
    fi

    write_ts "${LOCK_FILE}" "${at}"
    rm -f "${SESSION_FILE}"
    log "LOCKED at $(fmt_ts "${at}") (cooldown ${COOLDOWN_SECS}s)"
    echo "Locked until $(fmt_ts $(( at + COOLDOWN_SECS )))."
}

# --------------------- 3) daily cutoff time ---------------------------------

# True (0) if the current hour is inside the blocked window.
unlock_blocked_by_time() {
    local h
    h=$((10#$(date +%H)))
    if (( CUTOFF_HOUR > UNBLOCK_HOUR )); then
        (( h >= CUTOFF_HOUR || h < UNBLOCK_HOUR ))      # window wraps midnight
    else
        (( h >= CUTOFF_HOUR && h < UNBLOCK_HOUR ))
    fi
}

# --------------------------- 4) check / unlock ------------------------------

check() {
    ensure_state_dir || return 4
    expire_session_if_due

    if [[ -f "${SESSION_FILE}" ]]; then
        local end
        end=$(read_ts "${SESSION_FILE}")
        echo "Status: UNLOCKED (session active)"
        echo "Access: GRANTED"
        echo "Session ends: $(fmt_ts "${end}") ($(fmt_dur $(( end - $(now) ))) left)"
        return 0
    fi

    local rem
    rem=$(cooldown_remaining)
    if (( rem > 0 )); then
        echo "Status: LOCKED"
        echo "Access: DENIED"
        echo "Locked since: $(fmt_ts "$(read_ts "${LOCK_FILE}")")"
        echo "Time remaining: $(fmt_dur "${rem}")"
        echo "Can unlock: NO (after $(fmt_ts $(( $(now) + rem ))))"
        return 2
    fi

    if unlock_blocked_by_time; then
        echo "Status: READY (lock period over)"
        echo "Access: DENIED"
        printf 'Can unlock: NO (blocked %02d:00-%02d:00)\n' "${CUTOFF_HOUR}" "${UNBLOCK_HOUR}"
        return 3
    fi

    echo "Status: READY (lock period over, waiting for user action)"
    echo "Access: DENIED until you run unlock"
    echo "Can unlock: YES"
    return 1
}

# unlock - user action. Removes the lock file and starts the session timer.
unlock() {
    ensure_state_dir || return 4
    local out rc=0
    out=$(check) || rc=$?

    case "${rc}" in
        0) echo "Already unlocked."; echo "${out}"; return 0 ;;
        1) ;;                                   # allowed, continue below
        *) echo "Cannot unlock."; echo "${out}"; return 1 ;;
    esac

    rm -f "${LOCK_FILE}"
    start_timer
    log "UNLOCKED at $(fmt_ts "$(now)")"
    echo "Unlocked. Session ends $(fmt_ts "$(read_ts "${SESSION_FILE}")")."
}

# ------------------------------- CLI ----------------------------------------

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    set -euo pipefail
    rc=0
    case "${1:-}" in
        unlock)       unlock || rc=$? ;;
        check|status) check  || rc=$? ;;
        lock)         lock   || rc=$? ;;
        *)
            echo "Usage: $0 {unlock|check|status|lock}" >&2
            rc=64
            ;;
    esac
    exit "${rc}"
fi