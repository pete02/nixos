set -eu

system=x86_64-linux

packages="$(
nix eval --raw \
    --apply 'attrs: builtins.concatStringsSep "\n" (builtins.attrNames attrs)' \
    ".#packages.${system}"
)"

if [ -z "$packages" ]; then
echo "No packages exported for $system"
exit 0
fi

set --
while IFS= read -r package; do
[ -n "$package" ] || continue
set -- "$@" ".#packages.${system}.${package}"
done <<EOF
$packages
EOF

nix build \
--no-link \
--keep-going \
--max-jobs auto \
"$@"