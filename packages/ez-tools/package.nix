{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
  makeWrapper,
  dotnetCorePackages,
}:

# Eric Zimmerman's forensic CLI tools verified to parse real artifacts on Linux
# via .NET 9. Windows-native tools that only start but cannot parse on Linux are
# intentionally excluded (PECmd, SrumECmd, SumECmd, SQLECmd, WxTCmd, VSCMount).
let
  dotnet = dotnetCorePackages.aspnetcore_9_0;

  mkSource =
    name: hash:
    fetchurl {
      url = "https://download.mikestammer.com/net9/${name}.zip";
      inherit hash;
    };

  tools = [
    {
      name = "JLECmd";
      src = mkSource "JLECmd" "sha256-FV7lTmrGtwvOGqY27FLQsBZSY5M3ZNmkXIWvl99UaJI=";
    }
    {
      name = "LECmd";
      src = mkSource "LECmd" "sha256-8+nHmex9P6TNX1U+w/nVRMgMjkiv0E70NFbaPUitB2A=";
    }
    {
      name = "MFTECmd";
      src = mkSource "MFTECmd" "sha256-YK6FelVLgwJD446R+v399gZvMccDKCxcb0Da87ZNMWA=";
    }
    {
      name = "AmcacheParser";
      src = mkSource "AmcacheParser" "sha256-1A0eeGMVnb2ao66CbZGe3EkMoz34S95X6G2oSKWDrwM=";
    }
    {
      name = "AppCompatCacheParser";
      src = mkSource "AppCompatCacheParser" "sha256-Z3VoQdvNjKP0cIO+KwFqIvYb3g6jRQ8Kd2z4eL9m1C0=";
    }
    {
      name = "SBECmd";
      src = mkSource "SBECmd" "sha256-iO25ijK6r2gRSqEG8l+ZnkbTh9nQAD0yIqEWjMG365s=";
    }
    {
      name = "RECmd";
      src = mkSource "RECmd" "sha256-Sk4vS+ulT9ubpO615vnTI+ZmswnkB6yJ4Ef4K+DJY6I=";
      subdir = "RECmd";
      data = [
        "BatchExamples"
        "Plugins"
      ];
    }
    {
      name = "bstrings";
      src = mkSource "bstrings" "sha256-BjDSs6Un8oXIQH7Oje3c3f6SUxol4WwtX/0tYPuQ2MY=";
    }
    {
      name = "EvtxECmd";
      src = mkSource "EvtxECmd" "sha256-TXQOUcRTLDQNCA+DLHZsKssDUYMtrhGNGr6btJID+qQ=";
      subdir = "EvtxeCmd";
      data = [ "Maps" ];
    }
    {
      name = "RBCmd";
      src = mkSource "RBCmd" "sha256-4rXGuokpqHMdhhV3x5Z2NzDjA+wtTdjSlO4N6NXOtUE=";
    }
    {
      name = "RecentFileCacheParser";
      src = mkSource "RecentFileCacheParser" "sha256-UHMXY9M2lArjXSBXWwWL2gnzq7luRmK9YaXymUAXxG4=";
    }
  ];

  srcDir = tool: if (tool.subdir or "") == "" then tool.name else "${tool.name}/${tool.subdir}";
in
stdenvNoCC.mkDerivation {
  pname = "ez-tools";
  version = "2026.5.0";

  srcs = map (tool: tool.src) tools;

  nativeBuildInputs = [
    unzip
    makeWrapper
  ];

  dontConfigure = true;
  dontBuild = true;

  unpackPhase = ''
    runHook preUnpack
    ${lib.concatMapStringsSep "\n" (tool: ''
      mkdir -p ${tool.name}
      ${unzip}/bin/unzip -q ${tool.src} -d ${tool.name}
    '') tools}
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    ${lib.concatMapStringsSep "\n" (
      tool:
      let
        src = srcDir tool;
      in
      ''
        install -Dm644 ${src}/${tool.name}.dll $out/share/ez-tools/${tool.name}/${tool.name}.dll
        install -Dm644 ${src}/${tool.name}.runtimeconfig.json $out/share/ez-tools/${tool.name}/${tool.name}.runtimeconfig.json
        ${lib.concatMapStringsSep "\n" (
          dataDir: "cp -r ${src}/${dataDir} $out/share/ez-tools/${tool.name}/${dataDir}"
        ) (tool.data or [ ])}
        makeWrapper ${dotnet}/bin/dotnet $out/bin/${tool.name} \
          --add-flags "$out/share/ez-tools/${tool.name}/${tool.name}.dll" \
          --set DOTNET_ROOT ${dotnet} \
          --set DOTNET_CLI_TELEMETRY_OPTOUT 1 \
          --set DOTNET_SYSTEM_GLOBALIZATION_INVARIANT 1
      ''
    ) tools}
    runHook postInstall
  '';

  meta = {
    description = "Eric Zimmerman's Linux-compatible forensic CLI parsers";
    homepage = "https://ericzimmerman.github.io/";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "MFTECmd";
    sourceProvenance = with lib.sourceTypes; [ binaryBytecode ];
  };
}
