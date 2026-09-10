{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  python3,
}:

# Single-file Python script from raw.githubusercontent.com. Pure stdlib, no
# external deps. Pinned to a specific commit SHA in the raw path, not master.
stdenvNoCC.mkDerivation (_finalAttrs: {
  pname = "esetlogparser";
  version = "0.2.1-unstable-2017-09-28";

  src = fetchurl {
    url = "https://raw.githubusercontent.com/laciKE/EsetLogParser/5c4a915cc2c0bc6aadb44970e8a15a02dd031d1e/EsetLogParser.py";
    hash = "sha256-X5TXK7lgU/3SlInKotYIzhkeH6KwIcjMZuRpiN2DPJM=";
  };

  dontUnpack = true;

  nativeBuildInputs = [ makeWrapper ];
  buildInputs = [ python3 ];

  installPhase = ''
    runHook preInstall

    install -Dm755 "$src" "$out/libexec/esetlogparser/EsetLogParser.py"
    patchShebangs "$out/libexec/esetlogparser/EsetLogParser.py"
    makeWrapper ${lib.getExe python3} "$out/bin/esetlogparser" \
      --add-flags "$out/libexec/esetlogparser/EsetLogParser.py"

    runHook postInstall
  '';

  # The tool has --version but prints "EsetLogParser.py 0.2.1" (prog name), so
  # startability is proven via --help instead.

  meta = {
    description = "Parser for the ESET (NOD32) virlog.dat log file format";
    homepage = "https://github.com/laciKE/EsetLogParser";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.unix;
    mainProgram = "esetlogparser";
  };
})
