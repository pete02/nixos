#!/usr/bin/env bash
set -Eeuo pipefail

KEY_DIR="/etc/sops/age"
KEY_FILE="$KEY_DIR/keys.txt"

if [[ $EUID -ne 0 ]]; then
  echo "Run this script with sudo: sudo $0" >&2
  exit 1
fi

if [[ -e "$KEY_FILE" ]]; then
  echo "Age key already exists at $KEY_FILE; leaving it unchanged."
  exit 0
fi

if ! command -v age-keygen >/dev/null 2>&1; then
  echo "age-keygen is not installed." >&2
  echo "Install it with: nix shell nixpkgs#age" >&2
  exit 1
fi

install -d -o root -g root -m 700 "$KEY_DIR"

TEMP_KEY="$(mktemp)"
trap 'rm -f "$TEMP_KEY"' EXIT

age-keygen -o "$TEMP_KEY"

install -o root -g root -m 600 "$TEMP_KEY" "$KEY_FILE"

echo
echo "Age key installed at $KEY_FILE"
echo "Public key:"
age-keygen -y "$KEY_FILE"

