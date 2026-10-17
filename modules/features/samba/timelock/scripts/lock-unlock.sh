#!/usr/bin/env bash
set -euo pipefail

# lock-unlock.sh - User-based lock/unlock for samba timelock
# This script is called by the preexec/postexec hooks with the Samba username

STATE_DIR="@STATE_DIR@"
MAX_SESSION_SECS="@MAX_SESSION_SECS@"
CUTOFF_HOUR="@CUTOFF_HOUR@"

# Get the current user from Samba environment
SMB_USER="${SMB_USER:-${LOGNAME:-}}"
SMB_PID="${SMB_PID:-$$}"

log() {
    logger -t "samba-timelock" -- "User $SMB_USER (PID $SMB_PID): $*"
}

# Ensure state directory exists
ensure_state_dir() {
    if [[ ! -d "$STATE_DIR" ]]; then
        mkdir -p "$STATE_DIR"
        chmod 750 "$STATE_DIR"
    fi
}

# Get the state file path for a user
get_user_state_file() {
    local user="$1"
    echo "${STATE_DIR}/${user}.state"
}

# Get the timer file path for a user
get_user_timer_file() {
    local user="$1"
    echo "${STATE_DIR}/${user}.timer"
}

# Unlock the share for a user
unlock_share() {
    local user="$1"
    local state_file
    state_file=$(get_user_state_file "$user")
    
    ensure_state_dir
    
    local current_time
    current_time=$(date +%s)
    
    # Write unlock time
    echo "$current_time" > "$state_file"
    chmod 600 "$state_file"
    
    log "Unlocked share for user $user at $(date)"
}

# Lock the share for a user
lock_share() {
    local user="$1"
    local state_file
    state_file=$(get_user_state_file "$user")
    
    if [[ -f "$state_file" ]]; then
        rm -f "$state_file"
        log "Locked share for user $user"
    fi
}

# Check if user's share is currently unlocked
is_unlocked() {
    local user="$1"
    local state_file
    state_file=$(get_user_state_file "$user")
    
    [[ -f "$state_file" ]]
}

# Get unlock time for a user
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

# Calculate when the session should expire
get_expiry_time() {
    local user="$1"
    local unlock_time
    unlock_time=$(get_unlock_time "$user")
    
    if [[ "$unlock_time" == "0" ]]; then
        echo "0"
        return
    fi
    
    # Calculate expiry based on MAX_SESSION_SECS or CUTOFF_HOUR
    local current_hour
    current_hour=$(date +%H)
    
    if [[ "$current_hour" -ge "$CUTOFF_HOUR" ]]; then
        # Already past cutoff, expire after MAX_SESSION_SECS
        echo $((unlock_time + MAX_SESSION_SECS))
    else
        # Expire at CUTOFF_HOUR today
        local today_cutoff
        today_cutoff=$(date -d "$(date +%Y-%m-%d) ${CUTOFF_HOUR}:00:00" +%s)
        echo "$today_cutoff"
    fi
}

# Check if session has expired
session_expired() {
    local user="$1"
    local expiry_time
    expiry_time=$(get_expiry_time "$user")
    
    if [[ "$expiry_time" == "0" ]]; then
        return 0  # No valid session, considered expired
    fi
    
    local current_time
    current_time=$(date +%s)
    
    [[ "$current_time" -ge "$expiry_time" ]]
}

# Start a background timer for a user
start_timer() {
    local user="$1"
    local timer_file
    timer_file=$(get_user_timer_file "$user")
    
    # Kill any existing timer for this user
    if [[ -f "$timer_file" ]]; then
        local old_pid
        old_pid=$(cat "$timer_file")
        if kill -0 "$old_pid" 2>/dev/null; then
            kill "$old_pid" 2>/dev/null || true
        fi
    fi
    
    # Calculate sleep duration
    local expiry_time
    expiry_time=$(get_expiry_time "$user")
    
    if [[ "$expiry_time" == "0" ]]; then
        return
    fi
    
    local current_time
    current_time=$(date +%s)
    local sleep_secs=$((expiry_time - current_time))
    
    if [[ "$sleep_secs" -le 0 ]]; then
        # Already expired, lock immediately
        lock_share "$user"
        return
    fi
    
    # Start background timer process
    (
        sleep "$sleep_secs"
        lock_share "$user"
        rm -f "$timer_file"
    ) &
    
    local timer_pid=$!
    echo "$timer_pid" > "$timer_file"
    
    log "Started timer for user $user (expires in ${sleep_secs}s, PID $timer_pid)"
}

# Stop timer for a user
stop_timer() {
    local user="$1"
    local timer_file
    timer_file=$(get_user_timer_file "$user")
    
    if [[ -f "$timer_file" ]]; then
        local timer_pid
        timer_pid=$(cat "$timer_file")
        if kill -0 "$timer_pid" 2>/dev/null; then
            kill "$timer_pid" 2>/dev/null || true
        fi
        rm -f "$timer_file"
        log "Stopped timer for user $user"
    fi
}

# Main logic based on command
case "${1:-}" in
    unlock)
        unlock_share "$SMB_USER"
        start_timer "$SMB_USER"
        ;;
    lock)
        lock_share "$SMB_USER"
        stop_timer "$SMB_USER"
        ;;
    check)
        if session_expired "$SMB_USER"; then
            lock_share "$SMB_USER"
            exit 1
        fi
        exit 0
        ;;
    status)
        if is_unlocked "$SMB_USER"; then
            local unlock_time
            unlock_time=$(get_unlock_time "$SMB_USER")
            local expiry_time
            expiry_time=$(get_expiry_time "$SMB_USER")
            echo "Unlocked at: $(date -d @$unlock_time)"
            echo "Expires at: $(date -d @$expiry_time)"
            exit 0
        else
            echo "Locked"
            exit 1
        fi
        ;;
    *)
        echo "Usage: $0 {unlock|lock|check|status}" >&2
        exit 1
        ;;
esac
