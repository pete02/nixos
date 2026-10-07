{
description = "RPCS3 with fixed/reachable submodule revisions";

inputs = {
nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
};

outputs = {
self,
nixpkgs,
}: let
system = "x86_64-linux";
pkgs = import nixpkgs {
inherit system;
config.allowUnfreePredicate = pkg:
builtins.elem (pkgs.lib.getName pkg) [
"rpcs3"
];
};

```
rpcs3-src = pkgs.fetchFromGitHub {
  owner = "RPCS3";
  repo = "rpcs3";
  rev = "ea0d8a0d78";
  sha256 = "7607e0a50fca3202ff3b3782c86eaab0d6241bae8a8b1a54044c59eae8d64a66";
};

soundtouch = pkgs.fetchFromGitHub {
  owner = "RPCS3";
  repo = "soundtouch";
  rev = "3982730";
  sha256 = "cb05f2ac87d4cfaa78c6dd41f96688d9ce3eb684d0c067fc76ce7c45bfe4126a";
};

asmjit = pkgs.fetchFromGitHub {
  owner = "asmjit";
  repo = "asmjit";
  rev = "416f735";
  sha256 = "65ba9c3487da09af02db0c34405d1bdd3e49e134062930777f272007d97940fd";
};

yaml-cpp = pkgs.fetchFromGitHub {
  owner = "jbeder";
  repo = "yaml-cpp";
  rev = "g51a5d62";
  sha256 = "ff8c34735ac9e8ed7ecd096c03f06b2b4d1bc4b82a1bdd49543bc5c805c5230d";
};

openal-soft = pkgs.fetchFromGitHub {
  owner = "kcat";
  repo = "openal-soft";
  rev = "1.23.1";
  sha256 = "dfddf3a1f61059853c625b7bb03de8433b455f2f79f89548cbcbd5edca3d4a4a";
};

cubeb = pkgs.fetchFromGitHub {
  owner = "kinetiknz";
  repo = "cubeb";
  rev = "4848575";
  sha256 = "9f4c88716f3148767524775bb7efddf458473f922a6529c5784948077e39e738";
};

vulkan-memory-allocator = pkgs.fetchFromGitHub {
  owner = "Megamouse";
  repo = "VulkanMemoryAllocator";
  rev = "1d8f600";
  sha256 = "5aef11d98cd2d9a91d539e9baedeba55a0605a28d7ac8b01dc3d5254a13ca341";
};

stb = pkgs.fetchFromGitHub {
  owner = "nothings";
  repo = "stb";
  rev = "013ac3b";
  sha256 = "f2f5aeaa2504f8dc3ee7412cb480f9be218766c7a652ce3bcebbc25ec72d7e9c";
};

protobuf = pkgs.fetchFromGitHub {
  owner = "protocolbuffers";
  repo = "protobuf";
  rev = "edaa823d8b36";
  sha256 = "606447f35339c07246bcbef67d474103f1d7452e21c8b826566e60a92a7bf68f";
};

wolfssl = pkgs.fetchFromGitHub {
  owner = "wolfSSL";
  repo = "wolfssl";
  rev = "v5.9.1-stable";
  sha256 = "d5ca7af48cd2d9a91d539e9baedeba55a0605a28d7ac8b01dc3d5254a13ca341";
};

fusion = pkgs.fetchFromGitHub {
  owner = "xioTechnologies";
  repo = "Fusion";
  rev = "v1.2.11";
  sha256 = "5824b36f030db7530d4aa12a5de82d1e0e8688c607796d37dca8bb1573be80dc";
};

source = pkgs.runCommand "rpcs3-source-fixed" {} ''
  mkdir -p "$out"

  cp -a ${rpcs3-src}/. "$out/"

  mkdir -p "$out/3rdparty/SoundTouch/soundtouch"
  cp -a ${soundtouch}/. \
    "$out/3rdparty/SoundTouch/soundtouch/"

  mkdir -p "$out/3rdparty/asmjit/asmjit"
  cp -a ${asmjit}/. \
    "$out/3rdparty/asmjit/asmjit/"

  mkdir -p "$out/3rdparty/yaml-cpp/yaml-cpp"
  cp -a ${yaml-cpp}/. \
    "$out/3rdparty/yaml-cpp/yaml-cpp/"

  mkdir -p "$out/3rdparty/OpenAL/openal-soft"
  cp -a ${openal-soft}/. \
    "$out/3rdparty/OpenAL/openal-soft/"

  mkdir -p "$out/3rdparty/cubeb/cubeb"
  cp -a ${cubeb}/. \
    "$out/3rdparty/cubeb/cubeb/"

  mkdir -p "$out/3rdparty/GPUOpen/VulkanMemoryAllocator"
  cp -a ${vulkan-memory-allocator}/. \
    "$out/3rdparty/GPUOpen/VulkanMemoryAllocator/"

  mkdir -p "$out/3rdparty/stblib/stb"
  cp -a ${stb}/. \
    "$out/3rdparty/stblib/stb/"

  mkdir -p "$out/3rdparty/protobuf/protobuf"
  cp -a ${protobuf}/. \
    "$out/3rdparty/protobuf/protobuf/"

  mkdir -p "$out/3rdparty/wolfssl/wolfssl"
  cp -a ${wolfssl}/. \
    "$out/3rdparty/wolfssl/wolfssl/"

  mkdir -p "$out/3rdparty/fusion/fusion"
  cp -a ${fusion}/. \
    "$out/3rdparty/fusion/fusion/"
'';

rpcs3 = pkgs.rpcs3.overrideAttrs (old: {
  version = "0.0.40-19212-ea0d8a0d78";
  src = source;

  postPatch = ''
    ${old.postPatch or ""}
  '';
});
```

in {
packages.${system}.rpcs3 = rpcs3;

```
packages.${system}.default = rpcs3;
```

};
}
