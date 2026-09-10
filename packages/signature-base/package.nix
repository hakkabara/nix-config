{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

# Data-only package: YARA rules and IOCs for the LOKI scanner
# (pkgs/loki-scanner). No build, just copies signatures into
# $out/share/signature-base in the layout LOKI expects at
# `<app_path>/signature-base/` (yara/, iocs/, misc/).
#
# No binary -> no meta.mainProgram, so "signature-base" must be listed in
# `metaExempt` (flake.nix) or the meta check fails.
#
# License CC-BY-NC-4.0 (non-commercial): the NC clause is a licensing decision
# for use in a corporate pentest VM (CLAUDE.md §8).
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "signature-base";
  version = "2.0";

  src = fetchFromGitHub {
    owner = "Neo23x0";
    repo = "signature-base";
    tag = "v${finalAttrs.version}";
    hash = "sha256-4zBCoqYS+q3/xNofxnGNT45S26rxg65QA8GcFQI70iw=";
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/signature-base"
    cp -r yara iocs misc "$out/share/signature-base/"

    runHook postInstall
  '';

  # No executable to run; check that LOKI's required artefacts are present.

  meta = {
    description = "YARA rules and IOCs signature base for the LOKI IOC scanner";
    homepage = "https://github.com/Neo23x0/signature-base";
    license = lib.licenses.cc-by-nc-40;
    platforms = lib.platforms.all;
  };
})
