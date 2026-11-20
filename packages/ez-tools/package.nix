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
      src = mkSource "JLECmd" "sha256-WGe5ED5m7hYM6eTpO1sM0Vrjdmg6iVA8s/ldL9ws1uI=";
    }
    {
      name = "LECmd";
      src = mkSource "LECmd" "sha256-79hbpmlKSquJEhZT16VRL1RAZEjqvHtWnTZO2ffbLyo=";
    }
    {
      name = "MFTECmd";
      src = mkSource "MFTECmd" "sha256-85DOkHf5a880Vhp1yCkz8hQD+j5f2km8tzml3afN3Uc=";
    }
    {
      name = "AmcacheParser";
      src = mkSource "AmcacheParser" "sha256-3WDP4l81YO5IeOuGTiZjA4VetmCtqaOiZb+QYksPSBo=";
    }
    {
      name = "AppCompatCacheParser";
      src = mkSource "AppCompatCacheParser" "sha256-pnBRVq0W0zFjyth2dLa0yM7+aAFdtxG64VNyAHMmLOk=";
    }
    {
      name = "SBECmd";
      src = mkSource "SBECmd" "sha256-rrZkt0FrLVJ7ori53yGdgA5m5SNHh7NfB4ZDYKJhuEE=";
    }
    {
      name = "RECmd";
      src = mkSource "RECmd" "sha256-3N8y9bdXM8WnzW2fyXVyyEZrEc25z7Tqp9VkFsbh2uk=";
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
      src = mkSource "EvtxECmd" "sha256-79Wz35pSb61+LypiiRH224BVPj4EaMrvj56aSZJstdA=";
      subdir = "EvtxeCmd";
      data = [ "Maps" ];
    }
    {
      name = "RBCmd";
      src = mkSource "RBCmd" "sha256-4IQgRA59gdpKoPhXSMq1TD8tT6z/f/449DvKyEsxyjs=";
    }
    {
      name = "RecentFileCacheParser";
      src = mkSource "RecentFileCacheParser" "sha256-S34bt8ZO5mjeNNtHIsNdPoNeeCK4pQpYYZl8srdGJyM=";
    }
  ];

  srcDir = tool: if (tool.subdir or "") == "" then tool.name else "${tool.name}/${tool.subdir}";
in
stdenvNoCC.mkDerivation {
  pname = "ez-tools";
  version = "2026.10.0";

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
