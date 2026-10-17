#!/usr/bin/env bash
set -euo pipefail

# lock-unlock.sh - User-based lock/unlock for samba timelock
# Called by Samba preexec/postexec hooks with the Samba username.

STATE_DIR=""
MAX_SESSION_SECS=""
CUTOFF_HOUR=""
ACTION=""
USER=""

# Parse command-line arguments.
while [[ $# -gt 0 ]]; do
    case "$1" in
        --state-dir|--max-session-secs|--cutoff-hour|--user)
            if [[ $# -lt 2 || "$2" == --* ]]; then
                echo "Error: $1 requires a value" >&2
                exit 2
            fi

            case "$1" in
                --state-dir)
                    STATE_DIR="$2"
                    ;;
                --max-session-secs)
                    MAX_SESSION_SECS="$2"
                    ;;
                --cutoff-hour)
                    CUTOFF_HOUR="$2"
                    ;;
                --user)
                    USER="$2"
                    ;;
            esac
            shift 2
            ;;
        *)
            if [[ -n "$ACTION" ]]; then
                echo "Error: unexpected argument '$1'" >&2
                exit 2
            fi
            ACTION="$1"
            shift
            ;;
    esac
done

# Defaults supplied by the environment or Nix substitutions.
STATE_DIR="${STATE_DIR:-@STATE_DIR@}"
MAX_SESSION_SECS="${MAX_SESSION_SECS:-@MAX_SESSION_SECS@}"
CUTOFF_HOUR="${CUTOFF_HOUR:-@CUTOFF_HOUR@}"

# Get the user from the argument or Samba environment.
SMB_USER="${USER:-${SMB_USER:-${LOGNAME:-}}}"
SMB_PID="${SMB_PID:-$$}"

log() {
    logger -t "samba-timelock" -- \
        "User ${SMB_USER:-unknown} (PID $SMB_PID): $*" || true
}

# Validate configuration.
validate_config() {
    if [[ -z "$STATE_DIR" ]]; then
        echo "Error: state directory is not configured" >&2
        return 1
    fi

    if [[ ! "$MAX_SESSION_SECS" =~ ^[0-9]+$ ]] ||
        (( MAX_SESSION_SECS <= 0 )); then
        echo "Error: MAX_SESSION_SECS must be a positive integer" >&2
        return 1
    fi

    if [[ ! "$CUTOFF_HOUR" =~ ^[0-9]+$ ]] ||
        (( 10#$CUTOFF_HOUR > 23 )); then
        echo "Error: CUTOFF_HOUR must be between 0 and 23" >&2
        return 1
    fi

    if [[ -z "$SMB_USER" ]]; then
        echo "Error: no Samba username supplied" >&2
        return 1
    fi

    # Restrict usernames to safe filename characters.
    if [[ ! "$SMB_USER" =~ ^[a-zA-Z0-9_.@-]+$ ]]; then
        echo "Error: invalid username '$SMB_USER'" >&2
        return 1
    fi
}

# Ensure the state directory exists.
ensure_state_dir() {
    if [[ ! -d "$STATE_DIR" ]]; then
        mkdir -p "$STATE_DIR"
        chmod 750 "$STATE_DIR"
    fi
}

# Get the state file path for a user.
get_user_state_file() {
    printf '%s/%s.state\n' "$STATE_DIR" "$1"
}

# Get the timer file path for a user.
get_user_timer_file() {
    printf '%s/%s.timer\n' "$STATE_DIR" "$1"
}

# Unlock the share for a user.
unlock_share() {
    local user="$1"
    local state_file
    state_file=$(get_user_state_file "$user")

    ensure_state_dir

    local current_time
    current_time=$(date +%s)

    printf '%s\n' "$current_time" > "$state_file"
    chmod 600 "$state_file"

    log "Unlocked share for user $user at $(date)"
}

# Lock the share for a user.
lock_share() {
    local user="$1"
    local state_file
    state_file=$(get_user_state_file "$user")

    if [[ -f "$state_file" ]]; then
        rm -f "$state_file"
        log "Locked share for user $user"
    fi
}

# Check whether a user's share is currently unlocked.
is_unlocked() {
    local user="$1"
    local state_file
    state_file=$(get_user_state_file "$user")

    [[ -f "$state_file" ]]
}

# Get the unlock timestamp for a user.
get_unlock_time() {
    local user="$1"
    local state_file
    state_file=$(get_user_state_file "$user")

    if [[ -f "$state_file" ]]; then
        cat "$state_file"
    else
        echo "0"
    fi
}

# Calculate when the session should expire.
get_expiry_time() {
    local user="$1"
    local unlock_time
    unlock_time=$(get_unlock_time "$user")

    if [[ ! "$unlock_time" =~ ^[0-9]+$ ]] ||
        [[ "$unlock_time" == "0" ]]; then
        echo "0"
        return
    fi

    local current_hour
    current_hour=$(date +%H)

    if (( 10#$current_hour >= CUTOFF_HOUR )); then
        # If already at or past cutoff, use the maximum session duration.
        echo $((unlock_time + MAX_SESSION_SECS))
    else
        # Otherwise, expire at today's cutoff.
        local today_cutoff
        today_cutoff=$(date -d \
            "$(date +%Y-%m-%d) ${CUTOFF_HOUR}:00:00" +%s)
        echo "$today_cutoff"
    fi
}

# Check whether the session has expired.
session_expired() {
    local user="$1"
    local expiry_time
    expiry_time=$(get_expiry_time "$user")

    if [[ "$expiry_time" == "0" ]]; then
        return 0
    fi

    local current_time
    current_time=$(date +%s)

    (( current_time >= expiry_time ))
}

# Check whether unlocking is currently allowed.
unlock_allowed() {
    local user="$1"

    if is_unlocked "$user"; then
        log "Unlock rejected for user $user: already unlocked"
        return 1
    fi

    local current_hour
    current_hour=$(date +%H)

    if (( 10#$current_hour >= CUTOFF_HOUR )); then
        log "Unlock rejected for user $user: cutoff hour ($CUTOFF_HOUR) reached"
        return 1
    fi

    return 0
}

# Check whether MAX_SESSION_SECS has elapsed since unlocking.
max_session_elapsed() {
    local user="$1"
    local unlock_time
    unlock_time=$(get_unlock_time "$user")

    if [[ ! "$unlock_time" =~ ^[0-9]+$ ]] ||
        [[ "$unlock_time" == "0" ]]; then
        return 1
    fi

    local current_time
    current_time=$(date +%s)

    (( current_time >= unlock_time + MAX_SESSION_SECS ))
}

# Start a background timer for a user.
start_timer() {
    local user="$1"
    local timer_file
    timer_file=$(get_user_timer_file "$user")

    ensure_state_dir

    # Stop any existing timer for this user.
    stop_timer "$user"

    local expiry_time
    expiry_time=$(get_expiry_time "$user")

    if [[ "$expiry_time" == "0" ]]; then
        return 1
    fi

    local current_time
    current_time=$(date +%s)
    local sleep_secs=$((expiry_time - current_time))

    if (( sleep_secs <= 0 )); then
        lock_share "$user"
        return 0
    fi

    # Start a background timer.
    (
        sleep "$sleep_secs"

        # Only expire the session if it is still the same session.
        local current_unlock_time
        current_unlock_time=$(get_unlock_time "$user")

        if [[ "$current_unlock_time" == "$session_unlock_time" ]]; then
            lock_share "$user"
        fi

        rm -f "$timer_file"
    ) &

    local timer_pid=$!
    local session_unlock_time
    session_unlock_time=$(get_unlock_time "$user")

    printf '%s\n' "$timer_pid" > "$timer_file"
    chmod 600 "$timer_file"

    log "Started timer for user $user (expires in ${sleep_secs}s, PID $timer_pid)"
}

# Stop the background timer for a user.
stop_timer() {
    local user="$1"
    local timer_file
    timer_file=$(get_user_timer_file "$user")

    if [[ -f "$timer_file" ]]; then
        local timer_pid
        timer_pid=$(cat "$timer_file")

        if [[ "$timer_pid" =~ ^[0-9]+$ ]] &&
            kill -0 "$timer_pid" 2>/dev/null; then
            kill "$timer_pid" 2>/dev/null || true
        fi

        rm -f "$timer_file"
        log "Stopped timer for user $user"
    fi
}

# Check that required commands are available.
check_commands() {
    local missing=0

    for cmd in date mkdir rm cat sleep kill logger chmod; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo "Error: required command '$cmd' not found" >&2
            missing=1
        fi
    done

    return "$missing"
}

# Main command dispatch.
case "${ACTION:-}" in
    --check)
        if check_commands; then
            validate_config
            echo "All required commands are available"
            exit 0
        else
            exit 1
        fi
        ;;

    unlock)
        validate_config

        if ! unlock_allowed "$SMB_USER"; then
            exit 1
        fi

        unlock_share "$SMB_USER"
        start_timer "$SMB_USER"
        ;;

    lock)
        validate_config

        if ! is_unlocked "$SMB_USER"; then
            log "Lock rejected for user $SMB_USER: already locked"
            exit 1
        fi

        if ! max_session_elapsed "$SMB_USER"; then
            log "Lock rejected for user $SMB_USER: maximum session duration has not elapsed"
            exit 1
        fi

        lock_share "$SMB_USER"
        stop_timer "$SMB_USER"
        ;;

    check)
        validate_config

        if session_expired "$SMB_USER"; then
            lock_share "$SMB_USER"
            stop_timer "$SMB_USER"
            exit 1
        fi

        exit 0
        ;;

    status)
        validate_config

        if is_unlocked "$SMB_USER"; then
            unlock_time=$(get_unlock_time "$SMB_USER")
            expiry_time=$(get_expiry_time "$SMB_USER")

            echo "Unlocked at: $(date -d "@$unlock_time")"
            echo "Expires at: $(date -d "@$expiry_time")"
            exit 0
        else
            echo "Locked"
            exit 1
        fi
        ;;

    stop-timer)
        validate_config
        stop_timer "$SMB_USER"
        ;;

    get-unlock-time)
        validate_config
        get_unlock_time "$SMB_USER"
        ;;

    get-expiry-time)
        validate_config
        get_expiry_time "$SMB_USER"
        ;;

    *)
        echo "Usage: $0 [--state-dir DIR] [--max-session-secs SECS] [--cutoff-hour HOUR] [--user USER] <command>" >&2
        echo "Commands: --check, unlock, lock, check, status, stop-timer, get-unlock-time, get-expiry-time" >&2
        exit 1
        ;;
esac
