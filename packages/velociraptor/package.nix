{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}:

# Prebuilt official Linux release binary.
#
# Building from source is not possible offline: the server embeds a generated
# `assets` package (utils/reflect.go references assets.ReadFile), which is
# produced by the mage GUI pipeline (`npm ci && npm run build` + fileb0x). The
# `disable_gui` build tag does not stub that package out, so a network-free
# `go build` fails with `undefined: assets.ReadFile`. We therefore ship the
# upstream linux-amd64 binary.
#
# It is a dynamically linked glibc ELF with interpreter /lib64/ld-linux..., so
# autoPatchelfHook is mandatory on NixOS which has no FHS loader (CLAUDE.md §7).
stdenv.mkDerivation (finalAttrs: {
  pname = "velociraptor";
  version = "0.77.2";

  src = fetchurl {
    url = "https://github.com/Velocidex/velociraptor/releases/download/v${finalAttrs.version}/velociraptor-v${finalAttrs.version}-linux-amd64";
    hash = "sha256-bEwjxGbYkniP9W3c06MfhE5MDXl63kVMXiYl655CcHc=";
  };

  dontUnpack = true;
  dontBuild = true;

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [ stdenv.cc.cc.lib ];

  installPhase = ''
    runHook preInstall
    install -Dm755 $src $out/bin/velociraptor
    runHook postInstall
  '';

  meta = {
    description = "Endpoint visibility and collection tool for DFIR investigations and hunting";
    homepage = "https://github.com/Velocidex/velociraptor";
    changelog = "https://github.com/Velocidex/velociraptor/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.agpl3Only;
    platforms = [ "x86_64-linux" ];
    mainProgram = "velociraptor";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
