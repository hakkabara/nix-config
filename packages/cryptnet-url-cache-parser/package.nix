{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "cryptnet-url-cache-parser";
  version = "0.2.1";

  # Deliberately built from source instead of mirroring the release binary
  # (CLAUDE.md/TASKS.md): reproducible and without a foreign-loader dependency.
  src = fetchFromGitHub {
    owner = "AbdulRhmanAlfaifi";
    repo = "CryptnetURLCacheParser-rs";
    tag = "v${finalAttrs.version}";
    hash = "sha256-6YoGO9TNSfe2eA4UIrzlDvsIaCaEF8zX4CiW7nlcyZM=";
  };

  cargoHash = "sha256-H54NvTw9CqqL40huDAqKDoF1dL7SGs9NEJjE9fD1Qm0=";

  meta = {
    description = "Parser for Windows CryptnetURLCache metadata files";
    homepage = "https://github.com/AbdulRhmanAlfaifi/CryptnetURLCacheParser-rs";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    # Cargo builds the binary with underscores (see [[bin]] in Cargo.toml).
    mainProgram = "cryptnet_url_cache_parser";
  };
})
