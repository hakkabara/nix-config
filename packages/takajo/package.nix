{
  lib,
  stdenv,
  fetchurl,
  unzip,
  autoPatchelfHook,
  makeWrapper,
  curl,
  duckdb,
  sqlite,
}:

# Prebuilt Nim binary. NixOS has no FHS loader -> autoPatchelfHook is required
# (CLAUDE.md §7). Two quirks of this release zip:
#  1) The binary dlopens libcurl, libduckdb and libsqlite3 at runtime -- these
#     do not appear in DT_NEEDED, so autoPatchelfHook cannot find them on its
#     own. They are supplied via runtimeDependencies.
#  2) takajo looks for conf/, templates/ and mitre-attack.json RELATIVE TO CWD
#     and otherwise aborts with "run it from the directory where you unzipped
#     Takajo". Binary + resources therefore live together in $out/share/takajo
#     and the wrapper --chdir's into it.
stdenv.mkDerivation (finalAttrs: {
  pname = "takajo";
  version = "2.16.1";

  src = fetchurl {
    url = "https://github.com/Yamato-Security/takajo/releases/download/v${finalAttrs.version}/takajo-${finalAttrs.version}-lin-x64-gnu.zip";
    hash = "sha256-qsXi3l8Si5DwIC72uBujsEbewEDRnyhKfhfLXq6zWm4=";
  };

  nativeBuildInputs = [
    unzip
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    curl
    duckdb
    sqlite
  ];

  # Added to the binary's RPATH by autoPatchelfHook so the dlopen'd .so resolve.
  runtimeDependencies = [
    (lib.getLib curl)
    (lib.getLib duckdb)
    (lib.getLib sqlite)
  ];

  sourceRoot = ".";
  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/takajo $out/bin
    cp -r conf templates mitre-attack.json $out/share/takajo/
    install -Dm755 takajo-${finalAttrs.version}-lin-x64-gnu $out/share/takajo/takajo

    # takajo loads conf/ and templates/ relative to CWD -> chdir into the
    # resource directory.
    makeWrapper $out/share/takajo/takajo $out/bin/takajo \
      --chdir $out/share/takajo

    runHook postInstall
  '';

  meta = {
    description = "Analyzer for Hayabusa results and Windows event log JSON output";
    homepage = "https://github.com/Yamato-Security/takajo";
    changelog = "https://github.com/Yamato-Security/takajo/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.agpl3Only;
    platforms = [ "x86_64-linux" ];
    mainProgram = "takajo";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
