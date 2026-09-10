{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

# notatin pulls in bindgen via a C dependency, which needs libclang.

rustPlatform.buildRustPackage (_finalAttrs: {
  pname = "notatin";
  # No tagged release with the required fixes -- pinned commit.
  version = "0-unstable-2025-10-29";

  src = fetchFromGitHub {
    owner = "strozfriedberg";
    repo = "notatin";
    rev = "ae3a70611bc37b2ca04637671ceb14ccab9d5a87";
    hash = "sha256-K2tmQqD4nZ1K5TTEcLMVMN8sRFJ6XleM89J2pTNDRu8=";
  };

  cargoHash = "sha256-PDLoxYppqe6I7Vg1I3y3SHBXKowDTo+ZGwIZLMVOtYE=";

  # Without this feature notatin builds only the library, no CLI (reg_dump/reg_compare).
  buildFeatures = [ "build-binary" ];

  nativeBuildInputs = [ rustPlatform.bindgenHook ];

  meta = {
    description = "Rust parser for Windows registry hives, incl. deleted-key recovery";
    homepage = "https://github.com/strozfriedberg/notatin";
    license = lib.licenses.asl20;
    platforms = lib.platforms.unix;
    # notatin builds two binaries (reg_dump, reg_compare); reg_dump is the main CLI.
    mainProgram = "reg_dump";
  };
})
