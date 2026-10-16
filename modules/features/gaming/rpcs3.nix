
{ self,inputs, ... }: {
  flake.nixosModules.gaming-rpcs3 = { lib, pkgs, config, ... }: {
    options.gaming.rpcs3 =
      lib.mkEnableOption "RPCS3 PlayStation 3 emulator";

    config = lib.mkIf config.gaming.rpcs3 {
      environment.systemPackages = [
        self.packages.${pkgs.stdenv.hostPlatform.system}.rpcs3
      ];
    };
  };

  flake.packages.x86_64-linux.rpcs3 = let
    system = "x86_64-linux";

    pkgs = import inputs.nixpkgs-stable {
      inherit system;
      config.allowUnfreePredicate = pkg:
        builtins.elem (inputs.nixpkgs-stable.lib.getName pkg) [
          "rpcs3"
        ];
    };

    rpcs3Src = pkgs.fetchFromGitHub {
      owner = "RPCS3";
      repo = "rpcs3";
      rev = "ea0d8a0d78";
      hash = "sha256-7TNNNTKqY7bDHNl0/3sQkSB25dGPWWsGsm+/UqmGKTQ=";
    };

    sevenZipSrc = pkgs.fetchFromGitHub {
      owner = "ip7z";
      repo = "7zip";
      rev = "839151eaaad24771892afaae6bac690e31e58384";
      hash = "sha256-B+piugjEI7+8ILTuDitADY8XseltvV0lYIVecXGib7s=";
    };

    asmjitSrc = pkgs.fetchFromGitHub {
      owner = "asmjit";
      repo = "asmjit";
      rev = "416f7356967c1f66784dc1580fe157f9406d8bff";
      hash = "sha256-xhnzJwi0CD7lgRvk9Ctcfp8CP/Sg2d46c9PgDqbWgMI=";
    };

    fusionSrc = pkgs.fetchFromGitHub {
      owner = "xioTechnologies";
      repo = "Fusion";
      rev = "008e03eac0ac1d5f85e16f5fcaefdda3fee75cb8";
      hash = "sha256-9bqqP+6kfdRWIRnnP+R0lXSQs6OmZoNlbCjqiJeJjpk=";
    };

    wolfsslSrc = pkgs.fetchFromGitHub {
      owner = "wolfSSL";
      repo = "wolfssl";
      rev = "1d363f3adceba9d1478230ede476a37b0dcdef24";
      hash = "sha256-FyEb94hsO2BaTEi1CJRfCsUiT1xyWCzu7Uys81g2CBE=";
    };

    yamlCppSrc = pkgs.fetchFromGitHub {
      owner = "RPCS3";
      repo = "yaml-cpp";
      rev = "51a5d623e3fde1f58829a56ba910f1cb33596222";
      hash = "sha256-2b3dkgidPdAlMy8kJzM2FhlLm2zFGZc/BZLfd8mlAt4=";
    };

    soundTouchSrc = pkgs.fetchFromGitHub {
      owner = "RPCS3";
      repo = "soundtouch";
      rev = "a0fba77b6f9cfbdb71f8bbec58b6ac4e5e3b1097";
      hash = "sha256-uCx2956nlPUC3p/pZ0SupR+w8fZvOgJOnrRcpBqwqZI=";
    };

    stbSrc = pkgs.fetchFromGitHub {
      owner = "nothings";
      repo = "stb";
      rev = "013ac3beddff3dbffafd5177e7972067cd2b5083";
      hash = "sha256-cgoOF3MO88QIPSC0qEogOGbNsOEx4M33Z9Vtb/1n+2s=";
    };
    feralinteractiveSrc = pkgs.fetchFromGitHub {
      owner = "FeralInteractive";
      repo = "gamemode";
      rev = "c54d6d4243b0dd0afcb49f2c9836d432da171a2b";
      hash = "sha256-V0rewbSVOGFqJqXyCz4jXpuDM0EfjdkpGPl+WdDwI5I=";
    };
  in
    pkgs.rpcs3.overrideAttrs (old: {
      src = rpcs3Src;

      propagatedBuildInputs =
        (old.propagatedBuildInputs or [])
        ++ [
          pkgs.liberation_ttf
        ];
      version = "0.0.40-fixed";

      postInstall = ''
        mkdir -p $out/share/fonts

        cp ${pkgs.liberation_ttf}/share/fonts/truetype/LiberationSans-Regular.ttf \
          $out/share/fonts/Arial.ttf

        cp ${pkgs.liberation_ttf}/share/fonts/truetype/LiberationSans-Regular.ttf \
          $out/share/fonts/arial.ttf
      '';

      postPatch = ''
        rm -rf 3rdparty/7zip/7zip
        mkdir -p 3rdparty/7zip/7zip
        cp -r ${sevenZipSrc}/. 3rdparty/7zip/7zip/

        rm -rf 3rdparty/asmjit/asmjit
        mkdir -p 3rdparty/asmjit/asmjit
        cp -r ${asmjitSrc}/. 3rdparty/asmjit/asmjit/

        rm -rf 3rdparty/fusion/fusion
        mkdir -p 3rdparty/fusion/fusion
        cp -r ${fusionSrc}/. 3rdparty/fusion/fusion/

        rm -rf 3rdparty/wolfssl/wolfssl
        mkdir -p 3rdparty/wolfssl/wolfssl
        cp -r ${wolfsslSrc}/. 3rdparty/wolfssl/wolfssl/

        rm -rf 3rdparty/yaml-cpp/yaml-cpp
        mkdir -p 3rdparty/yaml-cpp/yaml-cpp
        cp -r ${yamlCppSrc}/. 3rdparty/yaml-cpp/yaml-cpp/

        rm -rf 3rdparty/SoundTouch/soundtouch
        mkdir -p 3rdparty/SoundTouch/soundtouch
        cp -r ${soundTouchSrc}/. 3rdparty/SoundTouch/soundtouch/

        rm -rf 3rdparty/stblib/stb
        mkdir -p 3rdparty/stblib/stb
        cp -r ${stbSrc}/. 3rdparty/stblib/stb/

        rm -rf 3rdparty/feralinteractive/feralinteractive
        mkdir -p 3rdparty/feralinteractive/feralinteractive
        cp -r ${feralinteractiveSrc}/. 3rdparty/feralinteractive/feralinteractive/


        echo "=== RPCS3 submodules ==="
        find 3rdparty/yaml-cpp/yaml-cpp -maxdepth 1 -type f -print
        find 3rdparty/asmjit/asmjit -maxdepth 1 -type f -print
        find 3rdparty/wolfssl/wolfssl -maxdepth 1 -type f -print
        find 3rdparty/fusion/fusion -maxdepth 1 -type f -print
      '';
      meta =
        old.meta
        // {
          description = "RPCS3 package with fixed reachable submodule revisions";
        };
    });
}