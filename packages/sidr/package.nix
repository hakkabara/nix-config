{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "sidr";
  version = "0.9.2";

  src = fetchFromGitHub {
    owner = "strozfriedberg";
    repo = "sidr";
    tag = "v${finalAttrs.version}";
    hash = "sha256-l6J+JJaFkFTDroMz6Ldnmq40OQGmEtL6l3ZFG6yk1GQ=";
  };

  cargoHash = "sha256-a9IHz0LwrYvPyNG9yOT2/OsC2EPBnaRLmPLv7FclZ/s=";

  checkFlags = [
    # Both tests invoke the built sidr binary via a relative path
    # (target/release/sidr) that does not exist in the Nix checkPhase -- they test
    # the CLI wiring, not the parser logic. The remaining 4 unit tests
    # (report/ese/utils) run unchanged.
    "--skip=ese::tests::warn_dirty"
    "--skip=compare_generated_reports"
  ];

  meta = {
    description = "Search Index Database Reporter for the Windows Search index (Windows.edb / Windows.db)";
    homepage = "https://github.com/strozfriedberg/sidr";
    changelog = "https://github.com/strozfriedberg/sidr/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.asl20;
    platforms = lib.platforms.unix;
    mainProgram = "sidr";
  };
})
