{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
  makeWrapper,
  dotnetCorePackages,
}:

# Eric Zimmerman's forensic CLI tools verified to parse real artifacts on Linux
# via .NET 10. Windows-native tools that only start but cannot parse on Linux are
# intentionally excluded (PECmd, SrumECmd, SumECmd, SQLECmd, WxTCmd, VSCMount).
let
  dotnet = dotnetCorePackages.aspnetcore_10_0;

  mkSource =
    name: hash:
    fetchurl {
      url = "https://download.mikestammer.com/net9/${name}.zip";
      inherit hash;
    };

  tools = [
    {
      name = "JLECmd";
      src = mkSource "JLECmd" "sha256-yza9orsqJUsriGxKMd+kgf7CCuQaaKV0SpUi3trvVM0=";
    }
    {
      name = "LECmd";
      src = mkSource "LECmd" "sha256-Yp77iFFETh8CfPUPtCZ621gVLQygzvNPNdKhT6B435I=";
    }
    {
      name = "MFTECmd";
      src = mkSource "MFTECmd" "sha256-cUSe0WycXASKZPd/U1NQVv36ZgB3vjSxMFzODFiieMc=";
    }
    {
      name = "AmcacheParser";
      src = mkSource "AmcacheParser" "sha256-TvnLw0n4bZ55Mb8AnZCV+fw2mwCs3Ie1uN8yEz/XnI8=";
    }
    {
      name = "AppCompatCacheParser";
      src = mkSource "AppCompatCacheParser" "sha256-7dBXRdPLQtYoqQ7WwE4s/fYN9Pv07XScB+bccDnmR+E=";
    }
    {
      name = "SBECmd";
      src = mkSource "SBECmd" "sha256-tnOmAWAbstOVebEE7Mqnd7MufEX21PCKr3YTd4m2DfI=";
    }
    {
      name = "RECmd";
      src = mkSource "RECmd" "sha256-QV2aqSVtV6xfoifk42+fcfxnT3+/rcXOQsiWu9nC1jE=";
      subdir = "RECmd";
      data = [
        "BatchExamples"
        "Plugins"
      ];
    }
    {
      name = "bstrings";
      src = mkSource "bstrings" "sha256-AB70AwoiPnSmknRZCEB5BQ+Xi6oalxmcKIBHuT0iXHc=";
    }
    {
      name = "EvtxECmd";
      src = mkSource "EvtxECmd" "sha256-OmMfVGa16djEp1wfln3ZQp/XtOk1vGw73vO6WLD8nSA=";
      subdir = "EvtxeCmd";
      data = [ "Maps" ];
    }
    {
      name = "RBCmd";
      src = mkSource "RBCmd" "sha256-VWrK47GSvdxLMgJFES0/ocBkkubpsj0TkbgDR78musU=";
    }
    {
      name = "RecentFileCacheParser";
      src = mkSource "RecentFileCacheParser" "sha256-zyEkbZZoUta08WhhLJZFQPB5ctn4eBNByDAIfvcn7ZU=";
    }
  ];

  srcDir = tool: if (tool.subdir or "") == "" then tool.name else "${tool.name}/${tool.subdir}";
in
stdenvNoCC.mkDerivation {
  pname = "ez-tools";
  # No upstream version: date of the pinned download set (2026-11-22).
  version = "2026.11.22";

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
          --set DOTNET_ROLL_FORWARD Major \
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
