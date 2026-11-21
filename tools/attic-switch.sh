#!/usr/bin/env bash
# Pull a NixOS system closure from the Attic cache (falling back to
# cache.nixos.org for paths Attic doesn't hold) and switch to it.
#
# Usage:
#   nixos-pull-switch.sh <system-store-path> [switch|boot|test]
#
# Environment overrides:
#   ATTIC_CACHE   Attic binary cache URL   (default: http://192.168.88.241:8889/main)
#   ATTIC_NETRC   netrc file with the token (default: /etc/nix/attic.netrc)
set -euo pipefail

ATTIC_CACHE="${ATTIC_CACHE:-http://192.168.88.241:8889/main}"
ATTIC_NETRC="${ATTIC_NETRC:-/etc/nix/attic.netrc}"

usage() {
  echo "usage: ${0##*/} <system-store-path> [switch|boot|test]" >&2
  exit 2
}

[ $# -ge 1 ] && [ $# -le 2 ] || usage
path="$1"
action="${2:-switch}"

case "$action" in
  switch | boot | test) ;;
  *) usage ;;
esac

case "$path" in
  *.drv)
    echo "error: got a .drv; pass the built system path (…-nixos-system-<host>-…)" >&2
    exit 2
    ;;
  /nix/store/*) ;;
  *)
    echo "error: not a /nix/store path: $path" >&2
    exit 2
    ;;
esac

# Everything below needs root (store writes, system profile, activation).
if [ "$(id -u)" -ne 0 ]; then
  exec sudo -E "$0" "$@"
fi

opts=(
  --option substituters "$ATTIC_CACHE https://cache.nixos.org"
  --option require-sigs false
)
if [ -r "$ATTIC_NETRC" ]; then
  opts+=(--option netrc-file "$ATTIC_NETRC")
else
  echo "warning: $ATTIC_NETRC not readable; Attic requests may get 401" >&2
fi

echo ">> Fetching $path"
nix-store --realise "$path" "${opts[@]}" >/dev/null

if [ ! -x "$path/bin/switch-to-configuration" ]; then
  echo "error: $path has no bin/switch-to-configuration (not a NixOS system?)" >&2
  exit 1
fi

# boot/switch register a new generation; test only activates.
if [ "$action" != "test" ]; then
  echo ">> Setting system profile"
  nix-env -p /nix/var/nix/profiles/system --set "$path"
fi

echo ">> switch-to-configuration $action"
exec "$path/bin/switch-to-configuration" "$action"