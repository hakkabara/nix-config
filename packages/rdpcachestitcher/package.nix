{
  lib,
  stdenv,
  fetchFromGitHub,
  libsForQt5,
  makeDesktopItem,
  copyDesktopItems,
}:

# RdpCacheStitcher (BSI) reassembles RDP bitmap cache tiles into reconstructed
# screen images -- a forensic aid that complements bmc-tools (which only extracts
# the individual tiles). It is a Qt5 Widgets GUI built with qmake; there is no
# CLI, no --help and no --version, and it prints nothing on startup. See the
# gui-start test and installCheckPhase for how "it actually runs" is verified
# without a display.
stdenv.mkDerivation (finalAttrs: {
  pname = "rdpcachestitcher";
  version = "1.1";

  src = fetchFromGitHub {
    owner = "BSI-Bund";
    repo = "RDPCacheStitcher";
    tag = "v${finalAttrs.version}";
    hash = "sha256-25TwIfuUAotWOzgTaLktlxxxe5YuHbf82VlFHhSlNIM=";
  };

  nativeBuildInputs = [
    libsForQt5.qmake
    libsForQt5.wrapQtAppsHook
    copyDesktopItems
  ];
  buildInputs = [ libsForQt5.qtbase ];

  # Newer Qt5 / GCC no longer pull the concrete event classes in transitively
  # via qwidget.h, so two translation units that dereference an event pointer
  # fail with "invalid use of incomplete type". Upstream's screenlabel.h already
  # includes <QMouseEvent> for exactly this reason; the other two files were
  # missed. Add the includes they need (--replace-fail aborts loudly if the
  # upstream include line ever drifts, so this cannot silently no-op).
  postPatch = ''
    NL=$'\n'
    substituteInPlace src/recommendationslabel.cpp \
      --replace-fail '#include "recommendationslabel.h"' \
      "#include \"recommendationslabel.h\"''${NL}#include <QMouseEvent>"
    substituteInPlace src/mainwindow.cpp \
      --replace-fail '#include "mainwindow.h"' \
      "#include \"mainwindow.h\"''${NL}#include <QCloseEvent>"
  '';

  # The project file (RdpCacheStitcher.pro) and all sources live in src/; qmake
  # must run there. preConfigure runs at the start of the qmake setup hook's
  # configurePhase, before qmake is invoked.
  preConfigure = "cd src";

  # The .pro defines no install target (upstream builds from Qt Creator), so the
  # binary is dropped in the build dir. Install it and let wrapQtAppsHook wrap it
  # in fixupPhase.
  installPhase = ''
    runHook preInstall
    install -Dm755 RdpCacheStitcher "$out/bin/RdpCacheStitcher"
    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "rdpcachestitcher";
      desktopName = "RdpCacheStitcher";
      exec = "RdpCacheStitcher";
      comment = "Reconstruct screen images from RDP bitmap cache tiles";
      categories = [
        "Utility"
        "Security"
      ];
    })
  ];

  # No --version flag exists, so versionCheckHook cannot be used. Instead the
  # install check proves the wrapped binary launches on a headless machine, using
  # the same two probes as smokeTests.mkGuiStartTest (see tests/smoke.nix): a
  # bogus platform must make Qt list "offscreen" among its plugins (they resolve
  # from the store), and launching under offscreen must reach a live event loop
  # that only `timeout` can stop (rc 124/137/143).

  meta = {
    description = "Reconstruct screen images from RDP bitmap cache tiles";
    homepage = "https://github.com/BSI-Bund/RDPCacheStitcher";
    license = lib.licenses.lgpl3Plus;
    platforms = lib.platforms.linux;
    mainProgram = "RdpCacheStitcher";
  };
})
