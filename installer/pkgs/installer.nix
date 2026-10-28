{ lib, writeShellScriptBin, bash, coreutils, util-linux, gnugrep, gnutar, findutils
, gptfdisk, parted, dosfstools, e2fsprogs, zstd, git, bundledFlake }:
let
  deps = [ coreutils util-linux gnugrep gnutar findutils gptfdisk parted dosfstools e2fsprogs zstd git ];
in
writeShellScriptBin "nixos-installer" ''
  export PATH=${lib.makeBinPath deps}:$PATH
  export BUNDLED_FLAKE=${bundledFlake}
  exec ${bash}/bin/bash ${../scripts/nixos-installer.sh} "$@"
''
