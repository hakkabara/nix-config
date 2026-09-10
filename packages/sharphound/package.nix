{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
}:

# SharpHound, the C#/.NET Active Directory collector for BloodHound (SpecterOps).
#
# ROUTE (CLAUDE.md §7/§8): SharpHound compiles to a Windows PE executable and is
# RUN ON A WINDOWS TARGET, not on this Linux DFIR/pentest VM. There is no
# Linux-runnable form -- the release ships SharpHound.exe (a .NET Framework
# assembly) plus SharpHound.ps1 (a reflective in-memory loader). We therefore
# STAGE the official release under $out/share/sharphound for transfer to a target;
# it is a data package, not a runnable program (hence no mainProgram, metaExempt).
#
# Because it is a foreign Windows binary, the §7 purity test (ldd / interpreter)
# does NOT apply -- there is no ELF and nothing to patchelf. The meaningful test
# is a PE-validity fixture test on the staged .exe (see passthru.tests.pe).
#
# LICENSE: GPL-3.0 (verified via the GitHub license API) -- a free license that
# permits redistribution, so this is NOT unfree and needs no allowedUnfreeNames
# entry. The release zip is pinned by tag + SRI hash and fetched directly; unlike
# ez-tools/dexray no manual mirror is required.

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "sharphound";
  version = "2.14.0";

  src = fetchurl {
    url = "https://github.com/SpecterOps/SharpHound/releases/download/v${finalAttrs.version}/SharpHound_v${finalAttrs.version}_windows_x86.zip";
    hash = "sha256-GxgSrl/KDJoqIOLU5P/LazhbgxKSSMiUwFqrDCSyBxU=";
  };

  nativeBuildInputs = [ unzip ];

  # The release zip is flat (files sit in the archive root), so the default
  # unpackPhase bails with "produced no directories" -- unpack into a subdir.
  unpackPhase = ''
    runHook preUnpack
    mkdir -p sharphound
    unzip -q "$src" -d sharphound
    runHook postUnpack
  '';

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm644 sharphound/SharpHound.exe        $out/share/sharphound/SharpHound.exe
    install -Dm644 sharphound/SharpHound.exe.config $out/share/sharphound/SharpHound.exe.config
    install -Dm644 sharphound/SharpHound.ps1        $out/share/sharphound/SharpHound.ps1

    runHook postInstall
  '';

  meta = {
    description = "Active Directory data collector for BloodHound (Windows target binary)";
    homepage = "https://github.com/SpecterOps/SharpHound";
    changelog = "https://github.com/SpecterOps/SharpHound/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.gpl3Only;
    # Staged Windows binary transferred to a target; no Linux program to run here.
    platforms = lib.platforms.all;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
