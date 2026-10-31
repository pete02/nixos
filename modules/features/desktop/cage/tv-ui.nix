
{...}: {
  perSystem = {pkgs, system, ...}: let
    lib = pkgs.lib;

    version = "3ce94ef";

    sources = {
      x86_64-linux = {
        url = "https://git.lumilukko.com/Pete/tv-ui/releases/download/build-20261031-1727-3ce94ef/tv-ui-3ce94ef-x86_64-linux.tar.gz";
        hash = "sha256-fvF6AvnsUVKPLSnXmZ3BSc2fc0bLrBGuvoOUvYDvjNM=";
      };

      aarch64-linux = {
        url = "https://git.lumilukko.com/Pete/tv-ui/releases/download/build-20261031-1727-3ce94ef/tv-ui-3ce94ef-aarch64-linux.tar.gz";
        hash = "sha256-wJDJ9Gu6E/ufqpWe0hr4hDHuEpHkTIkd5gY5JEMJ/ds=";
      };
    };

    source =
      sources.${system}
      or (throw "tv-ui does not support ${system}");

  in {
    packages.tv-ui = pkgs.stdenv.mkDerivation {
      pname = "tv-ui";
      inherit version;
    
      src = pkgs.fetchurl {
        inherit (source) url hash;
          netrcImpureEnvVars = ["FORGEJO_TOKEN"];

          netrcPhase = ''
            cat > netrc <<EOF
            machine git.lumilukko.com
            login pete
            password $FORGEJO_TOKEN
            EOF
          '';
      };

      sourceRoot = "tv-ui-${version}-${system}";

      nativeBuildInputs = with pkgs; [
        autoPatchelfHook
        makeWrapper
      ];

      buildInputs = with pkgs; [
        stdenv.cc.cc.lib
        openssl
        zlib
      ];

      dontBuild = true;

      installPhase = ''
        runHook preInstall

        install -Dm755 bin/tv-ui-server \
          $out/libexec/tv-ui-server

        mkdir -p $out/share/tv-ui
        cp -r share/tv-ui/web $out/share/tv-ui/web

        mkdir -p $out/bin

        makeWrapper $out/libexec/tv-ui-server \
          $out/bin/tv-ui-server \
          --set TV_WEB_DIR "$out/share/tv-ui/web"

        runHook postInstall
      '';

      meta = {
        description = "TV UI application server and web frontend";
        homepage = "https://git.lumilukko.com/Pete/tv-ui";
        mainProgram = "tv-ui-server";
        platforms = builtins.attrNames sources;
      };
    };
  };
}
