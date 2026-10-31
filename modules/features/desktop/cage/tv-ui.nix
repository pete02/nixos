
{self, ...}: {
  perSystem = {pkgs, ...}: {
    packages.tv-ui = let
      version = "3b4a044";

      src = pkgs.fetchurl {
        url = "https://git.lumilukko.com/Pete/tv-ui/releases/download/build-20261030-1906-3b4a044/tv-ui-${version}.tar.gz";
        hash = "sha256-6ySWDvfCrB7y7pSCYT5PfbYB4Jsc5REmCEQnWtQZSTE=";
      };
    in
      pkgs.stdenv.mkDerivation {
        pname = "tv-ui";
        inherit version src;

        sourceRoot = "tv-ui-${version}";

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
          description = "TV UI media frontend and server";
          homepage = "https://git.lumilukko.com/Pete/tv-ui";
          license = pkgs.lib.licenses.mit;
          mainProgram = "tv-ui-server";
          platforms = ["x86_64-linux"];
        };
      };
  };
}
