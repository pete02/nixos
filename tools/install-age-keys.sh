
#!/usr/bin/env bash
set -euo pipefail

DEST="/etc/sops/age/keys.txt"
FORCE=false

usage() {
  echo "Usage: $0 [--force] <age-keys-file>" >&2
  exit 2
}

while (($#)); do
  case "$1" in
    --force)
      FORCE=true
      shift
      ;;
    -*)
      usage
      ;;
    *)
      break
      ;;
  esac
done

[[ $# -eq 1 ]] || usage
SOURCE=$1

if [[ ! -f "$SOURCE" || ! -r "$SOURCE" ]]; then
  echo "Error: key file is not readable: $SOURCE" >&2
  exit 1
fi

if ! grep -qE '^[[:space:]]*AGE-SECRET-KEY-' "$SOURCE"; then
  echo "Error: no Age private key found in $SOURCE" >&2
  exit 1
fi

if [[ -e "$DEST" && "$FORCE" != true ]]; then
  echo "Error: $DEST already exists; refusing to overwrite." >&2
  echo "Use --force to replace it." >&2
  exit 1
fi

sudo install -d -o root -g root -m 700 "$(dirname "$DEST")"

TEMP=$(sudo mktemp "${DEST}.XXXXXX")
cleanup() {
  sudo rm -f "$TEMP"
}
trap cleanup EXIT

sudo install -o root -g root -m 600 "$SOURCE" "$TEMP"
sudo mv -f "$TEMP" "$DEST"
trap - EXIT

echo "Age key installed at $DEST"
echo "Permissions: root-only (0600)"
echo "No SOPS files or NixOS configuration were modified."
