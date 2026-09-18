
#!/usr/bin/env bash
set -euo pipefail

# Configuration
AGH_URL="${AGH_URL:-http://aria.local:8081}"
AGH_USERNAME="${AGH_USERNAME:-pete}"
AGH_PASSWORD="${AGH_PASSWORD:?AGH_PASSWORD must be set}"

CLIENT_NAME="raysha.local"
CLIENT_MAC="88:d8:2e:ba:62:29"

# Resolve the current IPv4 address of raysha.local.
CLIENT_IP="$(getent ahostsv4 "$CLIENT_NAME" | awk 'NR==1 {print $1}')"

if [[ -z "$CLIENT_IP" ]]; then
    echo "Error: could not resolve $CLIENT_NAME to an IPv4 address." >&2
    exit 1
fi

API="${AGH_URL%/}/control"

# Use a temporary netrc file so the password isn't passed directly as a
# command-line argument to curl.
NETRC="$(mktemp)"
trap 'rm -f "$NETRC"' EXIT
chmod 600 "$NETRC"

cat > "$NETRC" <<EOF
machine ${AGH_URL#*://}
login $AGH_USERNAME
password $AGH_PASSWORD
EOF

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
    echo "  off     Disable parental filtering, keep Safe Search enabled"
    echo "  status  Show the current configuration"
}

main() {
    case "${1:-}" in
        on)
            local client
            client="$(ensure_client)"

            update_client true "$client"
            clear_cache
            echo "raysha.local: parental filtering ON, Safe Search ON"
            ;;

        off)
            local client
            client="$(ensure_client)"

            update_client false "$client"

            echo "raysha.local: parental filtering OFF, Safe Search OFF"
            ;;

        status)
            local client
            client="$(ensure_client)"

            show_status "$client"
            ;;

        *)
            usage >&2
            exit 2
            ;;
    esac
}

main "$@"

