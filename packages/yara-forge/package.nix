{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
}:

# Data package: YARA Forge consolidated rule set. YARA Forge collects, dedupes
# and quality-checks YARA rules from 40+ public repositories and publishes them
# as three tiered, single-file packages (core / extended / full). We ship the
# "full" set -- all operational rules -- as one concatenated .yar under
# $out/share/yara-forge, consumed by yara / yara-x / the LOKI scanner.
#
# No binary -> no meta.mainProgram. The package must be listed in `metaExempt`
# (flake.nix), otherwise the meta check fails.
#
# License: the bundle mixes several licenses that YARA Forge preserves per-rule
# in each rule's `license` meta field. In the full set these are Detection Rule
# License 1.1 (the majority, Florian Roth's permissive DRL -- the successor to
# the old CC-BY-NC signature-base terms), CC-BY-SA-4.0, CC-BY-4.0, BSD-2-Clause,
# Apache-2.0 and MIT. All are free and redistributable; there are no
# non-commercial rules in this tier, so no allowedUnfreeNames entry is needed.
# nixpkgs has no drl11 attribute yet; drl10 is the closest match (DRL 1.1 only
# clarifies the attribution wording and is likewise free/commercial-friendly).
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "yara-forge";
  # Release tags are datestamps (YYYYMMDD); pin an exact tag, never a rolling one.
  version = "20260823";

  src = fetchurl {
    url = "https://github.com/YARAHQ/yara-forge/releases/download/${finalAttrs.version}/yara-forge-rules-full.zip";
    hash = "sha256-GobdaWpiBIt924sizPsolGsmknaNGDZDY65K+3UZKgY=";
  };

  nativeBuildInputs = [ unzip ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/yara-forge"
    # unpackPhase strips the single top-level "packages/" dir into sourceRoot.
    cp full/yara-rules-full.yar "$out/share/yara-forge/"

    runHook postInstall
  '';

  # A rule bundle is only useful if the rules actually compile. The real test is
  # therefore a compile against yara-x (`yr compile`), not just a file-exists
  # check. mkFixtureTest points at the installed rule file and fails on any
  # compile error; the layout test guards against an upstream repackaging.

  meta = {
    description = "Consolidated and quality-checked YARA rule set from public repositories";
    homepage = "https://github.com/YARAHQ/yara-forge";
    # Per-rule licenses preserved in the bundle; all free/redistributable.
    license = with lib.licenses; [
      drl10 # Detection Rule License (bundle uses 1.1; drl11 not in nixpkgs)
      cc-by-sa-40
      cc-by-40
      bsd2
      asl20
      mit
    ];
    platforms = lib.platforms.all;
    # Data package without a binary -> no mainProgram (orchestrator: metaExempt).
  };
})
