#!/usr/bin/env bash
set -euo pipefail

CLIENT_NAME="@CLIENT_NAME@"
CLIENT_MAC="@CLIENT_MAC@"

# Runtime configuration:
#   1. Explicitly exported environment variables
#   2. /run/secret/agh
#
# The secret file is deliberately only read at runtime, never by check().
AGH_SECRET_FILE="/run/secrets/agh"

check() {
    echo "Checking curl..."
    command -v curl >/dev/null || return 1

    echo "Checking jq..."
    command -v jq >/dev/null || return 1

    echo "Checking getent..."
    command -v getent >/dev/null || return 1

    echo "Checking logger..."
    command -v logger >/dev/null || return 1

    echo "Checking awk..."
    command -v awk >/dev/null || return 1

    echo "Checking chmod..."
    command -v chmod >/dev/null || return 1
}

log() {
    logger -t raysha-filter -- "$*"
}

load_config() {
    # Environment variables take precedence over the secret file.
    if [[ -f "$AGH_SECRET_FILE" ]]; then
        # shellcheck disable=SC1090
        source "$AGH_SECRET_FILE"
    fi

    AGH_URL="${AGH_URL:-http://aria.local:8081}"
    AGH_USERNAME="${AGH_USERNAME:-}"
    AGH_PASSWORD="${AGH_PASSWORD:-}"

    if [[ -z "$AGH_USERNAME" ]]; then
        echo "Error: AGH_USERNAME is not configured." >&2
        exit 1
    fi

    if [[ -z "$AGH_PASSWORD" ]]; then
        echo "Error: AGH_PASSWORD is not configured." >&2
        exit 1
    fi
}

# Resolve the current IPv4 address of raysha.local.
resolve_client_ip() {
    local ip

    ip="$(getent ahostsv4 "$CLIENT_NAME" | awk 'NR==1 {print $1}')"

    if [[ -z "$ip" ]]; then
        echo "Error: could not resolve $CLIENT_NAME to an IPv4 address." >&2
        exit 1
    fi

    printf '%s\n' "$ip"
}

curl_agh() {
    curl \
        --silent \
        --show-error \
        --fail \
        --user "$AGH_USERNAME:$AGH_PASSWORD" \
        "$@"
}

get_client() {
    curl_agh "$API/clients" |
        jq --arg mac "$CLIENT_MAC" --arg ip "$CLIENT_IP" '
            .clients[]
            | select(
                (.ids // [] | any(. == $mac))
                or
                (.ids // [] | any(. == $ip))
                or
                (.name == "raysha.local")
            )
        '
}

ensure_client() {
    local client

    client="$(get_client || true)"

    if [[ -n "$client" ]]; then
        echo "$client"
        return
    fi

    log "Client $CLIENT_NAME ($CLIENT_IP) not configured; creating AdGuard Home client"

    echo "raysha.local is not configured in AdGuard Home; creating client..." >&2

    curl_agh \
        -X POST \
        -H 'Content-Type: application/json' \
        "$API/clients/add" \
        --data "$(jq -n \
            --arg name "$CLIENT_NAME" \
            --arg mac "$CLIENT_MAC" \
            --arg ip "$CLIENT_IP" '
            {
                name: $name,
                ids: [$mac, $ip],
                use_global_settings: false,
                filtering_enabled: true,
                parental_enabled: false,
                safebrowsing_enabled: false,
                safe_search: {
                    enabled: true,
                    bing: true,
                    duckduckgo: true,
                    ecosia: true,
                    google: true,
                    pixabay: true,
                    yandex: true,
                    youtube: true
                },
                use_global_blocked_services: true,
                blocked_services: []
            }
        ')" >/dev/null

    log "Client $CLIENT_NAME created"
    get_client
}

update_client() {
    local enabled="$1"
    local client="$2"

    echo "$client" |
        jq \
            --argjson enabled "$enabled" \
            --arg mac "$CLIENT_MAC" \
            --arg ip "$CLIENT_IP" '
            .ids = (
                (.ids // [])
                + [$mac, $ip]
                | unique
            )
            | .use_global_settings = false
            | .parental_enabled = $enabled
            | .safe_search = {
                enabled: $enabled,
                bing: $enabled,
                duckduckgo: $enabled,
                ecosia: $enabled,
                google: $enabled,
                pixabay: $enabled,
                yandex: $enabled,
                youtube: $enabled
            }
        ' |
        jq --arg name "$CLIENT_NAME" '{
            name: $name,
            data: .
        }' |
        curl_agh \
            -X POST \
            -H 'Content-Type: application/json' \
            "$API/clients/update" \
            --data-binary @- >/dev/null
}

clear_cache() {
    curl_agh \
        -X POST \
        "$API/cache_clear" >/dev/null
}

show_status() {
    local client="$1"

    echo "Client:       $CLIENT_NAME"
    echo "IP:           $CLIENT_IP"
    echo "MAC:          $CLIENT_MAC"
    echo

    echo "$client" | jq -r '
        "Filtering:   \(
            if .filtering_enabled == true then "ON"
            else "OFF"
            end
        )",

        "Parental:    \(
            if .parental_enabled == true then "ON"
            else "OFF"
            end
        )",

        "Safe Search: \(
            if .safe_search.enabled == true then "ON"
            else "OFF"
            end
        )",

        "Search engines:",
        "  Google:      \(if .safe_search.google == true then "ON" else "OFF" end)",
        "  Bing:        \(if .safe_search.bing == true then "ON" else "OFF" end)",
        "  DuckDuckGo:  \(if .safe_search.duckduckgo == true then "ON" else "OFF" end)",
        "  Ecosia:      \(if .safe_search.ecosia == true then "ON" else "OFF" end)",
        "  YouTube:     \(if .safe_search.youtube == true then "ON" else "OFF" end)"
    '
}

usage() {
    echo "Usage: $0 {on|off|status}"
    echo
    echo "  on      Enable parental filtering and Safe Search"
    echo "  off     Disable parental filtering and Safe Search"
    echo "  status  Show the current configuration"
}

main() {
    load_config

    CLIENT_IP="$(resolve_client_ip)"
    API="${AGH_URL%/}/control"

    case "${1:-}" in
        on)
            local client

            log "Switching $CLIENT_NAME ($CLIENT_IP) -> ON"

            client="$(ensure_client)"

            if update_client true "$client" && clear_cache; then
                log "Switched $CLIENT_NAME -> parental filtering ON, Safe Search ON"
                echo "raysha.local: parental filtering ON, Safe Search ON"
            else
                log "ERROR: Failed to switch $CLIENT_NAME -> ON"
                exit 1
            fi
            ;;

        off)
            local client

            log "Switching $CLIENT_NAME ($CLIENT_IP) -> OFF"

            client="$(ensure_client)"

            if update_client false "$client" && clear_cache; then
                log "Switched $CLIENT_NAME -> parental filtering OFF, Safe Search OFF"
                echo "raysha.local: parental filtering OFF, Safe Search OFF"
            else
                log "ERROR: Failed to switch $CLIENT_NAME -> OFF"
                exit 1
            fi
            ;;

        status)
            local client
            client="$(ensure_client)"

            show_status "$client"
            ;;

        --check)
            # This branch is intentionally unreachable because check mode
            # is handled before main().
            exit 0
            ;;

        *)
            usage >&2
            exit 2
            ;;
    esac
}

if [[ "${1:-}" == "--check" ]]; then
    check
    exit $?
fi

main "$@"