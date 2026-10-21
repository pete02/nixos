
#!/usr/bin/env bash
set -Eeuo pipefail

FLAKE_DIR="/etc/nixos"
LOG_DIR="$FLAKE_DIR/rebuild-logs"

if [[ $EUID -ne 0 ]]; then
  exec sudo -- "$0" "$@"
fi

cd "$FLAKE_DIR"

if ! command -v nix >/dev/null 2>&1; then
  echo "ERROR: Nix is unavailable." >&2
  exit 1
fi

echo "Reading hosts from the NixOS flake..."

if ! HOSTS_JSON="$(
  nix --extra-experimental-features 'nix-command flakes' \
    eval --json '.#nixosConfigurations' --apply builtins.attrNames
)"; then
  echo "ERROR: Could not evaluate nixosConfigurations." >&2
  exit 1
fi

mapfile -t HOSTS < <(
  printf '%s' "$HOSTS_JSON" |
    nix --extra-experimental-features 'nix-command flakes' \
      shell nixpkgs#jq --command jq -r '.[]'
)

if [[ ${#HOSTS[@]} -eq 0 ]]; then
  echo "ERROR: The flake contains no NixOS configurations." >&2
  exit 1
fi

echo
echo "Available hosts:"
for host in "${HOSTS[@]}"; do
  printf '  %s\n' "$host"
done
echo

read -rp "Host to rebuild: " TARGET

if [[ ! " ${HOSTS[*]} " == *" $TARGET "* ]]; then
  echo "ERROR: '$TARGET' is not a host in this flake." >&2
  exit 1
fi

if ! command -v nixos-rebuild >/dev/null 2>&1; then
  echo "ERROR: nixos-rebuild is unavailable in PATH." >&2
  exit 1
fi

mkdir -p "$LOG_DIR"
chmod 755 "$LOG_DIR"

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
LOG_FILE="$LOG_DIR/${TARGET}-${TIMESTAMP}.log"

START_EPOCH="$(date +%s)"
START_TIME="$(date --iso-8601=seconds)"

echo "Host: $TARGET"
echo "Started: $START_TIME"
echo "Log: $LOG_FILE"
echo

set +e
nixos-rebuild switch --flake "$FLAKE_DIR#$TARGET" 2>&1 | tee "$LOG_FILE"
STATUS=${PIPESTATUS[0]}
set -e

END_EPOCH="$(date +%s)"
END_TIME="$(date --iso-8601=seconds)"
ELAPSED=$((END_EPOCH - START_EPOCH))

{
  echo
  echo "===== Rebuild summary ====="
  echo "Host: $TARGET"
  echo "Started: $START_TIME"
  echo "Finished: $END_TIME"
  echo "Elapsed: ${ELAPSED}s"
  echo "Exit status: $STATUS"
} | tee -a "$LOG_FILE"

echo
echo "Log saved to: $LOG_FILE"

exit "$STATUS"
