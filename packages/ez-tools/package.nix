{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
  makeWrapper,
  dotnetCorePackages,
}:

# Eric Zimmerman's JLECmd (jump lists) and LECmd (LNK files) as .NET 9 tools.
# Managed code -> no autoPatchelf needed; the native runtime comes from
# dotnetCorePackages.aspnetcore_9_0 (provides Microsoft.NETCore.App, which the
# two DLLs' runtimeconfig.json require).
#
# The net9 distribution exists upstream ONLY at the unversioned URL
# https://download.mikestammer.com/net9/<Tool>.zip (the GitHub releases carry
# only old .NET Framework builds without assets). As with DeXRAY, the zips are
# therefore mirrored once into the repo (CLAUDE.md §4/§8):
#
#   Source:    https://download.mikestammer.com/net9/{JLECmd,LECmd}.zip
#   Synced:    2026-05-05  (upstream Last-Modified of the zips)
#   Version per both tools' --help: 2026.5.0
#
# License: Eric Zimmerman's tools ship under no OSS license -> unfree (approved
# for use here; the flake predicate allows "ez-tools").
let
  dotnet = dotnetCorePackages.aspnetcore_9_0;

  jlecmdSrc = fetchurl {
    url = "https://download.mikestammer.com/net9/JLECmd.zip";
    hash = "sha256-FV7lTmrGtwvOGqY27FLQsBZSY5M3ZNmkXIWvl99UaJI=";
  };

  lecmdSrc = fetchurl {
    url = "https://download.mikestammer.com/net9/LECmd.zip";
    hash = "sha256-8+nHmex9P6TNX1U+w/nVRMgMjkiv0E70NFbaPUitB2A=";
  };
in
stdenvNoCC.mkDerivation (_finalAttrs: {
  pname = "ez-tools";
  version = "2026.5.0";

  # Both zips are flat (Tool.dll beside Tool.exe) -> unpack each into its own
  # subdirectory so the runtimeconfig.json files don't overwrite each other.
  unpackPhase = ''
    runHook preUnpack
    mkdir -p JLECmd LECmd
    ${unzip}/bin/unzip -q ${jlecmdSrc} -d JLECmd
    ${unzip}/bin/unzip -q ${lecmdSrc} -d LECmd
    runHook postUnpack
  '';

  nativeBuildInputs = [
    unzip
    makeWrapper
  ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share/ez-tools

    # The Windows .exe apphosts are useless on NixOS -> ship only the DLLs and
    # their runtimeconfig.json.
    install -Dm644 JLECmd/JLECmd.dll                 $out/share/ez-tools/JLECmd.dll
    install -Dm644 JLECmd/JLECmd.runtimeconfig.json  $out/share/ez-tools/JLECmd.runtimeconfig.json
    install -Dm644 LECmd/LECmd.dll                   $out/share/ez-tools/LECmd.dll
    install -Dm644 LECmd/LECmd.runtimeconfig.json    $out/share/ez-tools/LECmd.runtimeconfig.json

    for tool in JLECmd LECmd; do
      makeWrapper ${dotnet}/bin/dotnet $out/bin/$tool \
        --add-flags "$out/share/ez-tools/$tool.dll" \
        --set DOTNET_ROOT ${dotnet} \
        --set DOTNET_CLI_TELEMETRY_OPTOUT 1 \
        --set DOTNET_SYSTEM_GLOBALIZATION_INVARIANT 1
    done

    runHook postInstall
  '';

  meta = {
    description = "Eric Zimmerman's JLECmd (jump lists) and LECmd (LNK files) forensic parsers";
    homepage = "https://ericzimmerman.github.io/";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "JLECmd";
    sourceProvenance = with lib.sourceTypes; [ binaryBytecode ];
  };
})
