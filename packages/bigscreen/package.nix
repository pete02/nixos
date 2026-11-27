# Private Plasma Bigscreen for NixOS 26.05 (Plasma 6.6.x).
# Pinned to the last upstream commit that only requires Plasma >= 6.5.90.
{
  lib,
  fetchFromGitHub,
  mkKdeDerivation,
  pkg-config,
  # Qt
  qtmultimedia,
  qtwayland,
  qtwebengine,
  # KDE, build and runtime
  kdbusaddons,
  kglobalaccel,
  kirigami,
  kirigami-addons,
  kitemmodels,
  kdeconnect-kde,
  milou,
  plasma-nano,
  plasma-nm,
  plasma-pa,
  plasma-wayland-protocols,
  plasma-workspace,
  # Other
  qcoro,
  wayland,
  libcec,
  libcec_platform,
  sdl3,
}:
mkKdeDerivation {
  pname = "plasma-bigscreen";
  version = "6.6.90-unstable-2026-05-14";

  # GitHub is KDE's official mirror of invent.kde.org
  src = fetchFromGitHub {
    owner = "KDE";
    repo = "plasma-bigscreen";
    rev = "6a32f4fb5445afffa491691e9ef9921b5945268e";
    hash = "sha256-uPSARK25QiAIOWiQQJrPtirrIJbDQwzy+9MnqC3DnaU=";
  };

  postPatch = ''
    substituteInPlace bin/plasma-bigscreen-wayland.in \
      --replace-fail @KDE_INSTALL_FULL_LIBEXECDIR@ "${plasma-workspace}/libexec"

    substituteInPlace bin/plasma-bigscreen-wayland.desktop.cmake \
      --replace-fail @CMAKE_INSTALL_FULL_LIBEXECDIR@ "${plasma-workspace}/libexec"
  '';

  extraCmakeFlags = [ (lib.cmakeBool "QT_FIND_PRIVATE_MODULES" true) ];

  extraNativeBuildInputs = [ pkg-config ];

  extraBuildInputs = [
    qtmultimedia
    qtwayland
    qtwebengine
    kdbusaddons
    kglobalaccel
    kirigami
    kirigami-addons
    kitemmodels
    kdeconnect-kde
    milou
    plasma-nano
    plasma-nm
    plasma-pa
    plasma-wayland-protocols
    qcoro
    wayland
    libcec
    libcec_platform
    sdl3
  ];

  dontQmlLint = true;

  passthru.providedSessions = [ "plasma-bigscreen-wayland" ];

  # 26.05 has no generated license data for this package, so set meta here.
  meta = {
    description = "Plasma shell for TVs";
    homepage = "https://invent.kde.org/plasma/plasma-bigscreen";
    license = with lib.licenses; [ gpl2Plus lgpl2Plus ];
  };
}
