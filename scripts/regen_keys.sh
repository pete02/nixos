#!/usr/bin/env bash
# Regenerate SSH keypairs for every host and merge them into secrets.yaml
# under ssh.hosts.<host>.{private_key,public_key}, leaving everything else
# in the file untouched.
#
# Requires: ssh-keygen, sops, python3 with pyyaml
#   (nix-shell -p python3 python3Packages.pyyaml   if not already available)
#
# Usage: ./regen_keys.sh [path/to/secrets.yaml]

set -euo pipefail

SECRETS_FILE="${1:-secrets/secrets.yaml}"
HOSTS_DIR="/etc/nixos/modules/hosts"

if [[ ! -f "$SECRETS_FILE" ]]; then
  echo "error: $SECRETS_FILE not found" >&2
  exit 1
fi

if [[ ! -d "$HOSTS_DIR" ]]; then
  echo "error: $HOSTS_DIR not found — adjust HOSTS_DIR if hosts are declared elsewhere" >&2
  exit 1
fi

for cmd in ssh-keygen sops python3; do
  command -v "$cmd" >/dev/null || { echo "error: $cmd not found in PATH" >&2; exit 1; }
done

python3 -c "import yaml" 2>/dev/null || {
  echo "error: python3 module 'yaml' (PyYAML) not available." >&2
  echo "  try: nix-shell -p python3 python3Packages.pyyaml --run '$0 $*'" >&2
  exit 1
}

# Discover hosts: one subdirectory per host under /etc/nixos/hosts.
# Adjust this line if hosts are declared some other way (e.g. a single .nix file).
mapfile -t HOSTS < <(find "$HOSTS_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)

if [[ ${#HOSTS[@]} -eq 0 ]]; then
  echo "error: no hosts discovered under $HOSTS_DIR" >&2
  exit 1
fi

echo "Discovered hosts: ${HOSTS[*]}"

WORKDIR="$(mktemp -d)"
trap 'find "$WORKDIR" -type f -exec shred -u {} \; ; rm -rf "$WORKDIR"' EXIT

CURRENT_YAML="$WORKDIR/current.yaml"
MERGED_YAML="$WORKDIR/merged.yaml"
KEYS_JSON="$WORKDIR/keys.json"

# --- 1. Generate fresh keypairs, collect into a small JSON manifest ---

echo "{" > "$KEYS_JSON"
first=true
for host in "${HOSTS[@]}"; do
  priv_path="$WORKDIR/${host}_identity"
  ssh-keygen -t ed25519 -f "$priv_path" -N "" -C "$host" -q

  $first || echo "," >> "$KEYS_JSON"
  first=false

  python3 - "$host" "$priv_path" "${priv_path}.pub" >> "$KEYS_JSON" <<'PYEOF'
import json, sys
host, priv_path, pub_path = sys.argv[1:4]
with open(priv_path) as f:
    priv = f.read()
with open(pub_path) as f:
    pub = f.read().strip()
sys.stdout.write(json.dumps(host) + ": " + json.dumps({"private_key": priv, "public_key": pub}))
PYEOF

  echo "  generated keypair for $host"
done
echo "}" >> "$KEYS_JSON"

# --- 2. Decrypt current secrets, deep-merge new ssh.hosts.* over it ---

sops -d "$SECRETS_FILE" > "$CURRENT_YAML"

python3 - "$CURRENT_YAML" "$KEYS_JSON" "$MERGED_YAML" <<'PYEOF'
import sys, json, yaml

current_path, keys_json_path, merged_path = sys.argv[1:4]

with open(current_path) as f:
    data = yaml.safe_load(f) or {}

with open(keys_json_path) as f:
    new_hosts = json.load(f)

data.setdefault("ssh", {}).setdefault("hosts", {})
for host, keys in new_hosts.items():
    data["ssh"]["hosts"][host] = {
        "private_key": keys["private_key"],
        "public_key": keys["public_key"],
    }

# Render private_key as a literal block scalar ("|"), matching the style
# used elsewhere in secrets.yaml, instead of an escaped one-liner.
class LiteralStr(str):
    pass

def literal_str_representer(dumper, data):
    return dumper.represent_scalar("tag:yaml.org,2002:str", data, style="|")

yaml.add_representer(LiteralStr, literal_str_representer)

for host in new_hosts:
    data["ssh"]["hosts"][host]["private_key"] = LiteralStr(
        data["ssh"]["hosts"][host]["private_key"]
    )

with open(merged_path, "w") as f:
    yaml.dump(data, f, default_flow_style=False, sort_keys=False, width=4096)
PYEOF

# --- 3. Re-encrypt, into a temp file first, then atomically replace ---
#
# --filename-override tells sops to match .sops.yaml creation rules as if
# the input were at $SECRETS_FILE, even though it physically lives in
# $WORKDIR right now. Without this, sops matches against the tmp path and
# fails with "no matching creation rules found".
#
# We encrypt to a temp file in the SAME directory as $SECRETS_FILE (so the
# final `mv` is atomic, same filesystem) and only overwrite the real file
# once sops has exited successfully — never truncate-then-hope.

ENCRYPTED_TMP="$(mktemp "$(dirname "$SECRETS_FILE")/.secrets.yaml.XXXXXX")"
trap 'rm -f "$ENCRYPTED_TMP"; find "$WORKDIR" -type f -exec shred -u {} \; ; rm -rf "$WORKDIR"' EXIT

if ! sops --filename-override "$SECRETS_FILE" -e "$MERGED_YAML" > "$ENCRYPTED_TMP"; then
  echo "error: sops encryption failed — $SECRETS_FILE was NOT modified." >&2
  exit 1
fi

# Sanity check: the encrypted output must actually contain sops metadata
# before we trust it enough to overwrite the real file.
if ! grep -q '^sops:' "$ENCRYPTED_TMP"; then
  echo "error: encrypted output looks invalid (no sops metadata) — $SECRETS_FILE was NOT modified." >&2
  exit 1
fi

mv "$ENCRYPTED_TMP" "$SECRETS_FILE"

echo "Done. New keys merged into $SECRETS_FILE for: ${HOSTS[*]}"
echo "Review with: sops -d $SECRETS_FILE"
echo ""
echo "Next: rebuild servers (aria, raysha) before clients, so authorized_keys"
echo "and known_hosts templates pick up the new values in the right order."