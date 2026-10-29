#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 || -z "$1" ]]; then
  echo "Usage: $0 <hostname>" >&2
  exit 1
fi

host="$1"
secrets_file="/etc/nixos/secrets/secrets.yaml"

if [[ ! -f "$secrets_file" ]]; then
  echo "Error: SOPS file not found: $secrets_file" >&2
  exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

# Generate SSH identity keys
ssh-keygen -q -t ed25519 -N '' \
  -C "$host" -f "$tmpdir/ssh"

# Generate SSH host keys
ssh-keygen -q -t ed25519 -N '' \
  -C "$host-host" -f "$tmpdir/host"

# Set a SOPS value, JSON-encoding its contents on stdin.
set_secret() {
  local path="$1"
  local key_file="$2"

  jq -Rs . < "$key_file" |
    sops set --value-stdin "$secrets_file" "$path"
}

# Store keys in SOPS
set_secret "[\"ssh\"][\"hosts\"][\"$host\"][\"public_key\"]" \
  "$tmpdir/ssh.pub"

set_secret "[\"ssh\"][\"hosts\"][\"$host\"][\"private_key\"]" \
  "$tmpdir/ssh"

set_secret "[\"ssh\"][\"hosts\"][\"$host\"][\"host_key\"][\"public\"]" \
  "$tmpdir/host.pub"

set_secret "[\"ssh\"][\"hosts\"][\"$host\"][\"host_key\"][\"private\"]" \
  "$tmpdir/host"

echo "SSH keys generated and stored in SOPS for host: $host"
