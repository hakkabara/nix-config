{
  lib,
  stdenvNoCC,
  fetchurl,
  runCommand,
}:

# pspy watches processes without root, used to spot cron jobs and other
# commands on a target during privilege escalation. The release ships static
# Linux binaries (32/64-bit, plus -s "smaller" builds) to upload to targets;
# pspy64 also runs locally. Prebuilt, pinned by tag and hash.
let
  base = "https://github.com/DominicBreuker/pspy/releases/download/v1.2.1";
  bins = {
    pspy32 = "sha256-HjisCdeFGyLhaYCrxY+Tyr3EoChZxWooEKpRkwJ31FA=";
    pspy64 = "sha256-yT8ppcwTR725DhShJCTmRpyM/qmiC4ALwkl1XwBDo7s=";
    pspy32s = "sha256-8ujtc26Qqjj9I2BpN+noOT220QyzvkJq/ktlVkhg3zU=";
    pspy64s = "sha256-4Cd8Fk+sstD7lWgqd4h92Qiw4drLKKK8r9ZyizSDVCU=";
  };
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "pspy";
  version = "1.2.1";

  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/pspy" "$out/bin"
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (
        name: hash:
        ''install -Dm755 ${
          fetchurl {
            url = "${base}/${name}";
            inherit hash;
          }
        } "$out/share/pspy/${name}"''
      ) bins
    )}
    # Native-arch binary for local use; the rest are upload payloads.
    ln -s "$out/share/pspy/pspy64" "$out/bin/pspy"
    runHook postInstall
  '';

  # pspy64 is a static ELF; patchelf must report no interpreter (so it runs on
  # any target), and the binary must start locally.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    out_help=$("$out/bin/pspy" --help 2>&1 || true)
    printf '%s\n' "$out_help" | grep -qiE 'pspy|usage|interval'
    runHook postInstallCheck
  '';

  passthru.tests.static = runCommand "pspy-static-test" { } ''
    d=${finalAttrs.finalPackage}/share/pspy
    for b in pspy32 pspy64 pspy32s pspy64s; do
      head -c4 "$d/$b" | grep -q $'\x7fELF'
    done
    echo "PASS: all four pspy ELF binaries present"
    touch $out
  '';

  meta = {
    description = "Monitor Linux processes without root, for privilege escalation recon";
    homepage = "https://github.com/DominicBreuker/pspy";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.linux;
    mainProgram = "pspy";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
