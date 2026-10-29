
#!/usr/bin/env bash
set -Eeuo pipefail

KEY_DIR="/etc/sops/age"
ROOT_KEY="$KEY_DIR/keys.txt"
ATTIC_NETRC="/etc/nix/attic.netrc"

if [[ $EUID -ne 0 ]]; then
  exec sudo -- "$0" "$@"
fi

# Ask which Linux user's SOPS configuration to provision.
read -rp "Linux username: " USER_NAME

if [[ ! "$USER_NAME" =~ ^[a-z_][a-z0-9_-]*[$]?$ ]]; then
  echo "ERROR: Invalid username." >&2
  exit 1
fi

if ! id "$USER_NAME" >/dev/null 2>&1; then
  echo "ERROR: User '$USER_NAME' does not exist." >&2
  exit 1
fi

USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
USER_GROUP="$(id -gn "$USER_NAME")"
USER_KEY_DIR="$USER_HOME/.config/sops/age"
USER_KEY="$USER_KEY_DIR/keys.txt"

if [[ -z "$USER_HOME" || ! -d "$USER_HOME" ]]; then
  echo "ERROR: Could not determine the user's home directory." >&2
  exit 1
fi

# Read the token without displaying it.
read -rsp "Attic pull token: " ATTIC_TOKEN
echo

if [[ -z "$ATTIC_TOKEN" ]]; then
  echo "ERROR: The Attic pull token cannot be empty." >&2
  exit 1
fi

if ! command -v nix >/dev/null 2>&1; then
  echo "ERROR: Nix is not available." >&2
  exit 1
fi

# Obtain age-keygen through Nix.
AGE_KEYGEN=(nix --extra-experimental-features 'nix-command flakes' \
  shell nixpkgs#age --command age-keygen)

# Stage the key in a private temporary directory.
TEMP_DIR="$(mktemp -d)"
chmod 700 "$TEMP_DIR"
trap 'rm -rf "$TEMP_DIR"' EXIT
TEMP_KEY="$TEMP_DIR/keys.txt"

install -d -o root -g root -m 700 "$KEY_DIR"
install -d -o "$USER_NAME" -g "$USER_GROUP" -m 700 "$USER_KEY_DIR"

# Never silently replace an existing identity.
if [[ -f "$ROOT_KEY" && -f "$USER_KEY" ]]; then
  ROOT_PUBLIC="$("${AGE_KEYGEN[@]}" -y "$ROOT_KEY")"
  USER_PUBLIC="$("${AGE_KEYGEN[@]}" -y "$USER_KEY")"

  if [[ "$ROOT_PUBLIC" != "$USER_PUBLIC" ]]; then
    echo "ERROR: Root and user age keys differ." >&2
    echo "Resolve the mismatch manually; no keys were replaced." >&2
    exit 1
  fi

  cp "$ROOT_KEY" "$TEMP_KEY"
elif [[ -f "$ROOT_KEY" ]]; then
  cp "$ROOT_KEY" "$TEMP_KEY"
elif [[ -f "$USER_KEY" ]]; then
  cp "$USER_KEY" "$TEMP_KEY"
else
  echo "Generating a new age identity..."
  "${AGE_KEYGEN[@]}" -o "$TEMP_KEY"
fi

# Install the same private identity in both locations.
install -o root -g root -m 600 "$TEMP_KEY" "$ROOT_KEY"
install -o "$USER_NAME" -g "$USER_GROUP" -m 600 "$TEMP_KEY" "$USER_KEY"

# Install the Attic pull token in Nix netrc format.
install -d -o root -g root -m 755 /etc/nix
NETRC_TEMP="$TEMP_DIR/attic.netrc"

{
  printf 'machine 192.168.88.241\n'
  printf 'login attic-token\n'
  printf 'password %s\n' "$ATTIC_TOKEN"
} > "$NETRC_TEMP"

unset ATTIC_TOKEN
install -o root -g root -m 600 "$NETRC_TEMP" "$ATTIC_NETRC"

echo
echo "Bootstrap credentials installed."
echo "Root age key: $ROOT_KEY (root:root, 600)"
echo "User age key: $USER_KEY ($USER_NAME:$USER_GROUP, 600)"
echo "Attic netrc:  $ATTIC_NETRC (root:root, 600)"
echo
echo "Age public key:"
"${AGE_KEYGEN[@]}" -y "$ROOT_KEY"
echo
echo "Testing Attic authentication..."

HTTP_CODE="$(curl --silent --show-error \
  --netrc-file "$ATTIC_NETRC" \
  --output /dev/null \
  --write-out '%{http_code}' \
  http://192.168.88.241:8080/main/nix-cache-info)" || {
    echo "WARNING: Could not connect to Attic. Check network connectivity." >&2
    exit 1
  }

if [[ "$HTTP_CODE" != "200" ]]; then
  echo "ERROR: Attic returned HTTP $HTTP_CODE." >&2
  echo "Check the token and its permissions." >&2
  exit 1
fi

echo "Attic authentication succeeded."
echo "SOPS configuration and encrypted secrets were not modified."
echo "run build with --option netrc-file /etc/nix/attic.netrc option"