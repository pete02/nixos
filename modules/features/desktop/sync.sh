
#!/usr/bin/env bash
set -euo pipefail

check() {
    echo "Checking rsync..."
    command -v rsync >/dev/null
}

if [[ "${1:-}" == "--check" ]]; then
    check
    exit $?
fi

ENDPOINT="@ENDPOINT@"
HOME_DIR="@HOME@"

[ -d "$ENDPOINT" ] || exit 0

rsync -a \
    --exclude 'node_modules/' \
    --exclude 'target/' \
    --exclude '.venv/' \
    --exclude '.nix-venv/' \
    --exclude '.mypy_cache/' \
    --exclude '.pytest_cache/' \
    --exclude '.git/' \
    --exclude '.cargo/' \
    --exclude '*.mp4' \
    --exclude '/.*/' \
    --exclude 'dist/' \
    --info=progress2 \
    --delete \
    "$HOME_DIR/code" "$ENDPOINT"

rsync -a \
    --exclude 'node_modules/' \
    --exclude 'target/' \
    --exclude '.venv/' \
    --exclude '.nix-venv/' \
    --exclude '.mypy_cache/' \
    --exclude '.pytest_cache/' \
    --exclude '.git/' \
    --exclude '.cargo/' \
    --exclude 'dist/' \
    --info=progress2 \
    --delete \
    "$HOME_DIR/vaults" "$ENDPOINT"
