```bash
#!/usr/bin/env bash
set -euo pipefail
umask 077

: "${TIMELOCK_STATE_DIR:?TIMELOCK_STATE_DIR is required}"
: "${TIMELOCK_STATE_USER:?TIMELOCK_STATE_USER is required}"
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

[[ "$resource" =~ ^[a-zA-Z0-9_.-]+$ ]] ||
    die "Invalid resource name"

[[ "$TIMELOCK_MAX_SESSION_SECS" =~ ^[0-9]+$ ]] &&
    (( TIMELOCK_MAX_SESSION_SECS > 0 )) ||
    die "Invalid maximum session duration"

[[ "$TIMELOCK_COOLDOWN_SECS" =~ ^[0-9]+$ ]] ||
    die "Invalid cooldown duration"

[[ "$TIMELOCK_CUTOFF_HOUR" =~ ^[0-9]+$ ]] &&
    (( TIMELOCK_CUTOFF_HOUR <= 23 )) ||
    die "TIMELOCK_CUTOFF_HOUR must be an integer from 0 to 23"

for command_path in \
    "$TIMELOCK_LOCK_COMMAND" \
    "$TIMELOCK_UNLOCK_COMMAND"; do
    [[ -x "$command_path" ]] ||
        die "Command is missing or not executable: $command_path"
done

# Resolve the designated state owner's UID and primary group.
if ! state_uid=$(id -u "$TIMELOCK_STATE_USER"); then
    die "Unknown state user: $TIMELOCK_STATE_USER"
fi

if ! state_gid=$(id -g "$TIMELOCK_STATE_USER"); then
    die "Cannot resolve primary group for $TIMELOCK_STATE_USER"
fi

state_group=$(id -gn "$TIMELOCK_STATE_USER")

# Only root and the designated user may operate on this resource.
if (( EUID != 0 && EUID != state_uid )); then
    die "Run as root or as $TIMELOCK_STATE_USER"
fi

# Establish a private, user-owned state directory.
if (( EUID == 0 )); then
    install -d \
        -o "$state_uid" \
        -g "$state_gid" \
        -m 0700 \
        -- "$TIMELOCK_STATE_DIR"
else
    mkdir -p -- "$TIMELOCK_STATE_DIR"

    [[ -d "$TIMELOCK_STATE_DIR" && ! -L "$TIMELOCK_STATE_DIR" ]] ||
        die "State directory must be a real directory"

    [[ "$(stat -c '%u' -- "$TIMELOCK_STATE_DIR")" == "$state_uid" ]] ||
        die "State directory is not owned by $TIMELOCK_STATE_USER"

    chmod 0700 -- "$TIMELOCK_STATE_DIR"
fi

[[ -d "$TIMELOCK_STATE_DIR" && ! -L "$TIMELOCK_STATE_DIR" ]] ||
    die "State directory must be a real directory"

state_file="$TIMELOCK_STATE_DIR/$resource.state"
lock_file="$TIMELOCK_STATE_DIR/$resource.lock"

# Repair ownership of existing state files when invoked as root.
# Do this before opening the lock file.
if (( EUID == 0 )); then
    for file in "$state_file" "$lock_file"; do
        if [[ -e "$file" || -L "$file" ]]; then
            [[ -f "$file" && ! -L "$file" ]] ||
                die "State path is not a regular file: $file"

            chown "$state_uid:$state_gid" -- "$file"
            chmod 0600 -- "$file"
        fi
    done
fi

# Open/create the per-resource lock file.
if [[ -e "$lock_file" || -L "$lock_file" ]]; then
    [[ -f "$lock_file" && ! -L "$lock_file" ]] ||
        die "Lock path is not a regular file"
fi

exec 9>>"$lock_file"

if (( EUID == 0 )); then
    chown "$state_uid:$state_gid" -- "$lock_file"
    chmod 0600 -- "$lock_file"
else
    [[ "$(stat -c '%u' -- "$lock_file")" == "$state_uid" ]] ||
        die "Lock file is not owned by $TIMELOCK_STATE_USER"
fi

# Serialize transitions between root and user invocations.
flock -x 9

# Revalidate state after acquiring the lock.
if [[ -e "$state_file" || -L "$state_file" ]]; then
    [[ -f "$state_file" && ! -L "$state_file" ]] ||
        die "State path is not a regular file"
fi

if (( EUID == 0 )) && [[ -e "$state_file" ]]; then
    chown "$state_uid:$state_gid" -- "$state_file"
    chmod 0600 -- "$state_file"
fi

if (( EUID != 0 )) && [[ -e "$state_file" ]]; then
    [[ "$(stat -c '%u' -- "$state_file")" == "$state_uid" ]] ||
        die "State file is not owned by $TIMELOCK_STATE_USER"
fi

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
    local temporary

    temporary=$(mktemp "$TIMELOCK_STATE_DIR/.${resource}.state.XXXXXX")

    # Remove an incomplete temporary file if a write fails.
    trap 'rm -f -- "${temporary:-}"' RETURN

    printf '%s %s\n' "$new_state" "$timestamp" > "$temporary"
    chmod 0600 "$temporary"

    if (( EUID == 0 )); then
        chown "$state_uid:$state_gid" "$temporary"
    fi

    mv -f -- "$temporary" "$state_file"
    temporary=""

    trap - RETURN
}

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

expiry_time() {
    local unlocked_at="$1"
    local session_deadline=$((unlocked_at + TIMELOCK_MAX_SESSION_SECS))
    local today_cutoff

    today_cutoff=$(date -d "$(date +%F) $TIMELOCK_CUTOFF_HOUR:00:00" +%s)

    if (( today_cutoff <= unlocked_at )); then
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

        [[ "$STATE" == "locked" ]] ||
            die "$resource is already unlocked"

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

        [[ "$STATE" == "unlocked" ]] ||
            die "$resource is already locked"

        deadline=$((TIMESTAMP + TIMELOCK_MAX_SESSION_SECS))

        if (( $(now) < deadline )); then
            die "$resource cannot be manually locked before the maximum session duration"
        fi

        apply_lock "manual request"
        ;;

    expire)
        read_state

        [[ "$STATE" == "unlocked" ]] || exit 0

        deadline=$(expiry_time "$TIMESTAMP")

        if (( $(now) >= deadline )); then
            apply_lock "session expired"
        fi
        ;;

    check)
        read_state

        [[ "$STATE" == "unlocked" ]] || exit 1

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
```