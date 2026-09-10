{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  makeWrapper,
  python3,
}:

# Single-file Python tool, needs SQLAlchemy at runtime. Upstream has a stray
# `from unittest import result` that shadows a local `result` variable; the fix
# belongs in the package as a real postPatch, not a setup script (see below).
stdenvNoCC.mkDerivation (_finalAttrs: {
  pname = "eventtranscriptparser";
  version = "0-unstable-2023-09-13";

  src = fetchFromGitHub {
    owner = "stuxnet999";
    repo = "EventTranscriptParser";
    rev = "902eb3c773d5c0a63b0997ea0f1612e860f05c1c";
    hash = "sha256-Uprz4uLLMcTnR+ZsdLS6bz5l6TTe1dlGtnTFJIGlv5A=";
  };

  postPatch = ''
    substituteInPlace EventTranscriptParser.py \
      --replace-fail "from unittest import result" ""
  '';

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    install -Dm755 EventTranscriptParser.py "$out/libexec/eventtranscriptparser/EventTranscriptParser.py"
    makeWrapper ${
      (python3.withPackages (ps: [ ps.sqlalchemy ]))
    }/bin/python3 "$out/bin/eventtranscriptparser" \
      --add-flags "$out/libexec/eventtranscriptparser/EventTranscriptParser.py"

    runHook postInstall
  '';

  meta = {
    description = "Parser for the Windows Diagnostic Data EventTranscript.db database";
    homepage = "https://github.com/stuxnet999/EventTranscriptParser";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    mainProgram = "eventtranscriptparser";
  };
})
