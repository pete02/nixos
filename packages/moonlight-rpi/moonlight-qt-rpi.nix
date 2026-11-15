
{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  qt6,
  SDL2,
  SDL2_ttf,
  ffmpeg_8,
  libopus,
  openssl,
  alsa-lib,
  libpulseaudio,
  libdrm,
  libglvnd,
  mesa,
  wayland,
  libxkbcommon,
  zlib,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "moonlight-qt-rpi";
  version = "6.2.0";

  src = fetchurl {
    url = "https://dl.cloudsmith.io/public/moonlight-game-streaming/moonlight-qt/deb/raspbian/pool/main/m/moonlight-qt/moonlight-qt_6.2.0-1_arm64.deb";
    hash = lib.fakeHash;
  };

  dontUnpack = true;
  dontBuild = true;
  dontConfigure = true;

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    qt6.wrapQtAppsHook
  ];

  buildInputs = [
    qt6.qtbase
    qt6.qtdeclarative
    qt6.qtsvg
    qt6.qtwayland

    SDL2
    SDL2_ttf
    ffmpeg_8
    libopus
    openssl
    alsa-lib
    libpulseaudio
    libdrm
    libglvnd
    mesa
    wayland
    libxkbcommon
    zlib
  ];

  installPhase = ''
    runHook preInstall

    dpkg-deb -x "$src" "$out"

    mkdir -p "$out/bin"

    binary="$(find "$out/usr" -type f \
      -name 'moonlight*' -executable | head -n1)"

    if [ -z "$binary" ]; then
      echo "Could not find Moonlight executable in Debian package"
      find "$out" -type f
      exit 1
    fi

    ln -s "$binary" "$out/bin/moonlight"
    ln -s "$binary" "$out/bin/moonlight-qt"

    runHook postInstall
  '';

  meta = {
    description = "Official Raspberry Pi build of Moonlight Qt";
    homepage = "https://moonlight-stream.org";
    license = lib.licenses.gpl3Plus;
    platforms = [ "aarch64-linux" ];
    mainProgram = "moonlight";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
