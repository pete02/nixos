#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "--check" ]]; then
    exit 0
fi


pkill rpcs3 || true