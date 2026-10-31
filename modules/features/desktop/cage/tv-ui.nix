{...}: {
  perSystem = {
    pkgs,
    system,
    ...
  }: let
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

    tv-ui = pkgs.stdenv.mkDerivation {
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

    tv-ui-app = pkgs.writeShellApplication {
      name = "tv-ui-app";
      runtimeInputs = [tv-ui pkgs.chromium pkgs.curl pkgs.coreutils];
      text = ''
        export TV_BIND="''${TV_BIND:-0.0.0.0:8081}"
        port="''${TV_BIND##*:}"
        url="http://127.0.0.1:$port"

        # Secrets come from a file so they never sit in the unit environment.
        if [ -n "''${TMDB_API_KEY_FILE:-}" ]; then
          TMDB_API_KEY="$(cat "$TMDB_API_KEY_FILE")"
          export TMDB_API_KEY
        fi

        tv-ui-server &
        server=$!
        trap 'kill "$server" 2>/dev/null || true' EXIT

        ready=0
        for _ in $(seq 1 60); do
          if curl -sf -o /dev/null "$url"; then ready=1; break; fi
          kill -0 "$server" 2>/dev/null || { echo "tv-ui-server exited early" >&2; exit 1; }
          sleep 0.5
        done
        [ "$ready" = 1 ] || { echo "tv-ui-server did not come up" >&2; exit 1; }

        chromium \
          --kiosk --app="$url" \
          --ozone-platform=wayland \
          --user-data-dir="''${XDG_CACHE_HOME:-$HOME/.cache}/tv-ui-chromium" \
          --noerrdialogs --disable-infobars --no-first-run \
          --autoplay-policy=no-user-gesture-required
      '';
      meta.mainProgram = "tv-ui-app";
    };
  in {
    packages = {
      inherit tv-ui tv-ui-app;
    };
  };
}
