{
  lib,
  stdenvNoCC,
  fetchurl,
  bash,
  makeWrapper,
  runCommand,
}:

# PEASS-ng privilege-escalation scripts (linpeas / winPEAS), staged for upload
# to target systems. The payloads run on the TARGET; linpeas.sh also runs
# locally for self-enumeration. Prebuilt release assets, pinned by tag and
# hash (they are scripts and .NET/.bat payloads, not built here).
let
  tag = "20261121-c05a450f";
  base = "https://github.com/carlospolop/PEASS-ng/releases/download/${tag}";
  asset =
    name: hash:
    fetchurl {
      url = "${base}/${name}";
      inherit hash;
    };

  files = {
    "linpeas.sh" = asset "linpeas.sh" "sha256-fEDrh+Mnd8aYnDSsKOIEQ5INPLpQ+/V064iC3bTmgaY=";
    "linpeas_small.sh" = asset "linpeas_small.sh" "sha256-XpjRnvU648gxX9IS9Xg5KIBf6hJqPUrLGWBanKlF1Tw=";
    "winPEAS.bat" = asset "winPEAS.bat" "sha256-zUWg21KnqIfjRiLAr1Ac/NZ7ZSZ1F/6ZZL0tWvLp0aI=";
    "winPEASany.exe" = asset "winPEASany.exe" "sha256-SC+wr/l3g++DOMpGI7vz/LojCsotAB4BQNXuc+5E9rU=";
    "winPEASx64.exe" = asset "winPEASx64.exe" "sha256-oqJ8xQh9tqklVdp6J/lO3dMi38SnCT+VtY1Y54kz610=";
    "winPEASx86.exe" = asset "winPEASx86.exe" "sha256-zvLUyoWGa7qH5DfCktETvuIHcFeX3zG/pUKQ2xoQRN4=";
  };
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "peass-ng";
  version = "0-unstable-2026-11-21";

  dontUnpack = true;
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/peass"
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: file: ''install -Dm644 ${file} "$out/share/peass/${name}"'') files
    )}
    chmod +x "$out/share/peass/linpeas.sh" "$out/share/peass/linpeas_small.sh"

    # Convenience for self-enumeration on this host; the payloads are mainly
    # meant to be uploaded to targets from $out/share/peass.
    makeWrapper ${lib.getExe bash} "$out/bin/linpeas" \
      --add-flags "$out/share/peass/linpeas.sh"
    runHook postInstall
  '';

  # linpeas.sh -h prints its help offline; proves the payload is intact.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    out_help=$("$out/bin/linpeas" -h 2>&1 || true)
    printf '%s\n' "$out_help" | grep -qiE 'linpeas|usage|checks'
    test -s "$out/share/peass/winPEASx64.exe"
    runHook postInstallCheck
  '';

  passthru.tests.payloads = runCommand "peass-ng-payloads-test" { } ''
    d=${finalAttrs.finalPackage}/share/peass
    head -1 "$d/linpeas.sh" | grep -q '^#!'
    # Windows PE payloads start with the MZ magic.
    for exe in winPEASany.exe winPEASx64.exe winPEASx86.exe; do
      head -c2 "$d/$exe" | grep -q 'MZ'
    done
    grep -qi 'winpeas\|@echo' "$d/winPEAS.bat"
    echo "PASS: linpeas shebang, winPEAS PE/bat payloads present"
    touch $out
  '';

  meta = {
    description = "PEASS-ng privilege escalation scripts (linpeas, winPEAS) for upload to targets";
    homepage = "https://github.com/carlospolop/PEASS-ng";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
    mainProgram = "linpeas";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
