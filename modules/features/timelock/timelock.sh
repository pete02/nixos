#!/usr/bin/env bash
set -euo pipefail

: "${TIMELOCK_STATE_DIR:?TIMELOCK_STATE_DIR is required}"
: "${TIMELOCK_MAX_SESSION_SECS:=3600}"
: "${TIMELOCK_COOLDOWN_SECS:=259200}"
: "${TIMELOCK_CUTOFF_HOUR:=21}"
: "${TIMELOCK_LOCK_COMMAND:?TIMELOCK_LOCK_COMMAND is required}"
: "${TIMELOCK_UNLOCK_COMMAND:?TIMELOCK_UNLOCK_COMMAND is required}"

die() {
    echo "Error: $*" >&2
    exit 2
}

log() {
    logger -t timelock -- "$*" || true
}

[[ $# -eq 2 ]] || die "Usage: timelock RESOURCE ACTION"

resource="$1"
action="$2"

if [[ "$resource" =~ ^[a-zA-Z0-9_.-]+$ ]]; then
    die "Invalid resource name"
fi

if [[ "$TIMELOCK_MAX_SESSION_SECS" =~ ^[0-9]+$ ]] &&
    (( TIMELOCK_MAX_SESSION_SECS > 0 )); then
    die "Invalid maximum session duration"
fi
if [[ "$TIMELOCK_COOLDOWN_SECS" =~ ^[0-9]+$ ]]; then
    die "Invalid cooldown duration"
fi
if [[ ! "$TIMELOCK_CUTOFF_HOUR" =~ ^[0-9]+$ ]] ||
  (( TIMELOCK_CUTOFF_HOUR > 23 )); then
  die "TIMELOCK_CUTOFF_HOUR must be an integer from 0 to 23"
fi
for command_path in \
    "$TIMELOCK_LOCK_COMMAND" \
    "$TIMELOCK_UNLOCK_COMMAND"; do
    [[ -x "$command_path" ]] ||
        die "Command is missing or not executable: $command_path"
done

mkdir -p "$TIMELOCK_STATE_DIR"
chmod 750 "$TIMELOCK_STATE_DIR"

state_file="$TIMELOCK_STATE_DIR/$resource.state"
lock_file="$TIMELOCK_STATE_DIR/$resource.lock"

# Serialize state transitions for this resource.
exec 9>"$lock_file"
flock -x 9

now() {
    date +%s
}

read_state() {
    STATE="locked"
    TIMESTAMP=0

    if [[ -f "$state_file" ]]; then
        read -r STATE TIMESTAMP < "$state_file" ||
            die "Cannot read state for $resource"

        [[ "$STATE" == "locked" || "$STATE" == "unlocked" ]] ||
            die "Invalid state for $resource"

        [[ "$TIMESTAMP" =~ ^[0-9]+$ ]] ||
            die "Invalid timestamp for $resource"
    fi
}

write_state() {
    local new_state="$1"
    local timestamp="$2"
    local temporary="$state_file.tmp.$$"

    printf '%s %s\n' "$new_state" "$timestamp" > "$temporary"
    chmod 600 "$temporary"
    mv -f "$temporary" "$state_file"
}

# Apply the adapter's lock operation and persist the locked state.
apply_lock() {
    local reason="$1"
    local timestamp
    timestamp=$(now)

    if "$TIMELOCK_LOCK_COMMAND"; then
        write_state locked "$timestamp"
        log "$resource locked: $reason"
    else
        log "$resource lock operation failed: $reason"
        return 1
    fi
}

# Calculate the effective expiry deadline.
expiry_time() {
    local unlocked_at="$1"
    local session_deadline=$((unlocked_at + TIMELOCK_MAX_SESSION_SECS))

    local today_cutoff
    today_cutoff=$(date -d "$(date +%F) $TIMELOCK_CUTOFF_HOUR:00:00" +%s)

    if (( today_cutoff <= unlocked_at )); then
        # The cutoff has already passed today.
        printf '%s\n' "$session_deadline"
    elif (( today_cutoff < session_deadline )); then
        printf '%s\n' "$today_cutoff"
    else
        printf '%s\n' "$session_deadline"
    fi
}

case "$action" in
    unlock)
        read_state

        if [[ "$STATE" == "unlocked" ]]; then
            die "$resource is already unlocked"
        fi

        if (( TIMESTAMP > 0 && $(now) < TIMESTAMP + TIMELOCK_COOLDOWN_SECS )); then
            die "$resource is still in its cooldown period"
        fi

        current_hour=$(date +%H)
        if (( 10#$current_hour >= TIMELOCK_CUTOFF_HOUR )); then
            die "Unlocking $resource is prohibited after the daily cutoff"
        fi

        timestamp=$(now)

        if ! "$TIMELOCK_UNLOCK_COMMAND"; then
            log "$resource unlock operation failed"
            exit 1
        fi

        write_state unlocked "$timestamp"
        log "$resource unlocked"
        ;;

    lock)
        read_state

        if [[ "$STATE" != "unlocked" ]]; then
            die "$resource is already locked"
        fi

        deadline=$((TIMESTAMP + TIMELOCK_MAX_SESSION_SECS))

        if (( $(now) < deadline )); then
            die "$resource cannot be manually locked before the maximum session duration"
        fi

        apply_lock "manual request"
        ;;

    expire)
        read_state

        if [[ "$STATE" != "unlocked" ]]; then
            exit 0
        fi

        deadline=$(expiry_time "$TIMESTAMP")

        if (( $(now) >= deadline )); then
            apply_lock "session expired"
        fi
        ;;

    check)
        read_state

        if [[ "$STATE" != "unlocked" ]]; then
            exit 1
        fi

        deadline=$(expiry_time "$TIMESTAMP")

        if (( $(now) >= deadline )); then
            apply_lock "expired during access check"
            exit 1
        fi

        exit 0
        ;;

    status)
        read_state

        printf 'Resource: %s\nState: %s\n' "$resource" "$STATE"

        if [[ "$STATE" == "unlocked" ]]; then
            deadline=$(expiry_time "$TIMESTAMP")
            printf 'Unlocked at: %s\n' "$(date -d "@$TIMESTAMP")"
            printf 'Expires at: %s\n' "$(date -d "@$deadline")"
        else
            printf 'Locked at: %s\n' "$(date -d "@$TIMESTAMP")"

            if (( TIMESTAMP > 0 )); then
                printf 'Cooldown ends: %s\n' \
                    "$(date -d "@$((TIMESTAMP + TIMELOCK_COOLDOWN_SECS))")"
            fi
        fi
        ;;

    *)
        die "Unknown action: $action"
        ;;
esac