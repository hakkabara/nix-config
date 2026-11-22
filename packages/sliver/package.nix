{
  lib,
  stdenvNoCC,
  fetchurl,
  runCommand,
}:

# Sliver C2 framework (BishopFox). Prebuilt, statically linked Go release
# binaries for linux-amd64, pinned by tag and hash -- no patchelf needed.
#   sliver-server : runs the server and drops into the operator console
#                   (standalone use). `sliver` is an alias for it.
#   sliver-client : connects to a remote sliver server.
# On first run the server extracts its assets to ~/.sliver and generates
# certificates; it works offline.
let
  version = "1.7.9";
  base = "https://github.com/BishopFox/sliver/releases/download/v${version}";

  server = fetchurl {
    url = "${base}/sliver-server_linux-amd64";
    hash = "sha256-bFTqlJYfFd4iu3ZZEbhQ0FTmb2kGnkt5mrfMMTTo7zY=";
  };
  client = fetchurl {
    url = "${base}/sliver-client_linux-amd64";
    hash = "sha256-n2a9XVXsGQkFaIGEsCkDKg6MRU/4O3bJGIT2U4QgdnI=";
  };
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "sliver";
  inherit version;

  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 ${server} "$out/bin/sliver-server"
    install -Dm755 ${client} "$out/bin/sliver-client"
    ln -s sliver-server "$out/bin/sliver"
    runHook postInstall
  '';

  # Both binaries print the pinned version offline; proves they run on NixOS
  # (static Go, no interpreter) without a download.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    export HOME="$TMPDIR/home"
    "$out/bin/sliver-client" version | grep -q "v${version}"
    "$out/bin/sliver-server" version | grep -q "v${version}"
    runHook postInstallCheck
  '';

  passthru.tests.version = runCommand "sliver-version-test" { } ''
    export HOME="$TMPDIR/home"
    ${finalAttrs.finalPackage}/bin/sliver version | grep -q "v${version}"
    echo "PASS: sliver ${version} runs"
    touch $out
  '';

  meta = {
    description = "Adversary emulation and red team C2 framework (prebuilt binaries)";
    homepage = "https://github.com/BishopFox/sliver";
    changelog = "https://github.com/BishopFox/sliver/releases/tag/v${version}";
    license = lib.licenses.gpl3Only;
    platforms = [ "x86_64-linux" ];
    mainProgram = "sliver";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
