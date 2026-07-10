[ -d /mnt/server/desktopsync ] || exit 0
/run/current-system/sw/bin/rsync -a \
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
--delete /home/pete/code /mnt/server/desktopsync
/run/current-system/sw/bin/rsync -a \
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
--delete /home/pete/vaults /mnt/server/desktopsync