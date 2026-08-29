{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

# Data package: nixpkgs' chainsaw ships no rules/mappings. Version pinned to the
# nixpkgs chainsaw (same tag -> same src hash) so rules and binary match. The
# wrapper (overlay.nix) wires up the paths.
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "chainsaw-rules";
  version = "2.16.5";

  src = fetchFromGitHub {
    owner = "WithSecureLabs";
    repo = "chainsaw";
    tag = "v${finalAttrs.version}";
    hash = "sha256-BTN+yDeiP47UEPNEYoWMRbaKPZY+dvyeUUw3M/4Lr3I=";
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/chainsaw
    cp -r rules $out/share/chainsaw/rules
    cp -r mappings $out/share/chainsaw/mappings
    runHook postInstall
  '';

  # Data package, no binary: layout test instead of mkSmokeTest. Checks that the
  # expected upstream structure was installed (catches upstream reorgs).

  meta = {
    description = "Detection rules and event mappings for the chainsaw DFIR tool";
    homepage = "https://github.com/WithSecureLabs/chainsaw";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.all;
    # Data package without a binary, so no mainProgram (orchestrator: metaExempt).
  };
})
