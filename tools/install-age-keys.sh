
#!/usr/bin/env bash
set -Eeuo pipefail

KEY_DIR="/etc/sops/age"
KEY_FILE="$KEY_DIR/keys.txt"

# Re-execute as root when necessary.
if [[ $EUID -ne 0 ]]; then
  exec sudo -- "$0" "$@"
fi

# Do not replace an existing private key.
if [[ -e "$KEY_FILE" ]]; then
  echo "Age key already exists: $KEY_FILE"
  echo "Leaving it unchanged."
  exit 0
fi

# Nix is required to obtain age-keygen when it is not installed.
if ! command -v nix >/dev/null 2>&1; then
  echo "ERROR: Nix is not installed or unavailable in PATH." >&2
  exit 1
fi

install -d -o root -g root -m 700 "$KEY_DIR"

TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT
TEMP_KEY="$TEMP_DIR/keys.txt"

echo "Generating an age key using nixpkgs#age..."

# This obtains age-keygen through Nix without requiring a permanent install.
nix --extra-experimental-features 'nix-command flakes' shell nixpkgs#age --command age-keygen -o "$TEMP_KEY"

# Install the private key with restrictive permissions.
install -o root -g root -m 600 "$TEMP_KEY" "$KEY_FILE"

echo
echo "Age private key installed: $KEY_FILE"
echo "Directory permissions: 700"
echo "Key file permissions: 600"
echo
echo "Public key:"
nix --extra-experimental-features 'nix-command flakes' shell nixpkgs#age --command age-keygen -y "$KEY_FILE"

echo
echo "Done. No SOPS configuration or encrypted secrets were modified."
