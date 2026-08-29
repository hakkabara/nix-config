{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  zlib,
}:

# Hindsight (RyanDFIR fork) as a PyInstaller onefile release. This fork is the
# actively maintained one; obsidianforensics/hindsight's "latest" API points at
# RyanDFIR assets.
#
# PyInstaller onefile: an outer ELF shell with embedded CPython 3.13 and all .so.
# autoPatchelfHook patches the shell (interpreter + DT_NEEDED libz etc.). The
# embedded .so are unpacked to $TMPDIR/_MEIxxxx at runtime and loaded relative to
# it -- they need no FHS loader because the bootloader uses the already-patched
# process interpreter. The smoke test verifies this (real --help output, not just
# exit code).
#
# If this ever breaks (CLAUDE.md §7): do NOT paper over it with buildFHSEnv/nix-ld;
# switch to build-from-source (Python) and escalate.
stdenv.mkDerivation (finalAttrs: {
  pname = "hindsight";
  version = "2026.06";

  src = fetchurl {
    # Pinned to a concrete release tag, not the moving latest alias (CLAUDE.md §3.4).
    url = "https://github.com/RyanDFIR/hindsight/releases/download/v${finalAttrs.version}/hindsight-linux-x86_64";
    hash = "sha256-s/ifNN1ca9Zoc/IY7SbDxs6ECK5LMbZXcpNwPShQQ4Y=";
  };

  dontUnpack = true;

  nativeBuildInputs = [ autoPatchelfHook ];

  # DT_NEEDED of the outer shell: libz. libdl/libpthread/libc come from stdenv/glibc.
  buildInputs = [ zlib ];

  installPhase = ''
    runHook preInstall

    # The PyInstaller binary; autoPatchelfHook finds it here.
    install -Dm755 $src $out/libexec/hindsight/hindsight

    # Install the wrapper and substitute the binary path. The wrapper fixes
    # hindsight's read-only log path; see the file.
    install -Dm755 ${./hindsight-wrapper.sh} $out/bin/hindsight
    substituteInPlace $out/bin/hindsight \
      --replace-fail '@real@' "$out/libexec/hindsight/hindsight"
    patchShebangs $out/bin/hindsight

    runHook postInstall
  '';

  meta = {
    description = "Internet history forensics for Google Chrome/Chromium";
    homepage = "https://github.com/obsidianforensics/hindsight";
    changelog = "https://github.com/RyanDFIR/hindsight/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.asl20;
    platforms = [ "x86_64-linux" ];
    mainProgram = "hindsight";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
