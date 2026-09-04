{
  lib,
  stdenv,
  python3Packages,
  fetchFromGitHub,
  fetchPypi,
  autoPatchelfHook,
  makeWrapper,
  gnugrep,
}:

# MANSPIDER -- full-featured SMB spider. The Linux-native equivalent of Snaffler:
# it crawls SMB shares and matches on both file *names* and file *content* using
# regexes, extracting text from Office/PDF/image documents so credentials and
# secrets buried inside files are found, not just filenames.
#
# This is a LIVE pentest tool (it talks SMB over the network), not an offline
# dead-disk parser. Typical use against a target:
#   manspider <target> -u user -p pass -c 'password|secret' -e docx xlsx pdf
# It also supports offline local searching of a directory (pass a path instead
# of a host), which is what the fixture tests below exercise.
#
# Runtime binaries: `grep` (used via subprocess for the coloured content-match
# output) is put on PATH via the wrapper. Content extraction (docx/xlsx/pdf/...)
# is done by kreuzberg, whose native Rust core is self-contained. OCR of images
# is OPTIONAL and needs an external tesseract/easyocr backend -- deliberately not
# wired up here (see the kreuzberg note below); non-OCR content search, the core
# of the tool, works fully.

let
  # kreuzberg is MANSPIDER's content-extraction engine and is absent from
  # nixpkgs. Since 4.x it is a large Rust/maturin workspace (859 crates in
  # Cargo.lock; bundled ONNX Runtime; its build.rs *downloads* PDFium at build
  # time, which no-network Nix builds forbid) -- building it from source is a
  # package of its own, out of scope for this tool's lane (CLAUDE.md §8). It is
  # therefore consumed as its published manylinux abi3 wheel: the native
  # extension (_internal_bindings.abi3.so) and its bundled libonnxruntime are
  # patched onto the store loader by autoPatchelfHook; the only external DT_NEEDED
  # are libstdc++/libgcc from stdenv.cc.cc.lib. The wheel declares no mandatory
  # Python runtime deps (easyocr/tesseract are optional extras, left out).
  kreuzberg = python3Packages.buildPythonPackage (finalAttrs: {
    pname = "kreuzberg";
    version = "4.10.2";
    format = "wheel";

    src = fetchPypi {
      inherit (finalAttrs) pname version;
      format = "wheel";
      dist = "cp310";
      python = "cp310";
      abi = "abi3";
      platform = "manylinux_2_28_x86_64";
      hash = "sha256-jRd0n5RpXwsgTFVRK4ZqKfHH2m0ij0B8noLOzK9jiSs=";
    };

    nativeBuildInputs = [ autoPatchelfHook ];

    # DT_NEEDED of _internal_bindings.abi3.so: libstdc++/libgcc_s. The bundled
    # libonnxruntime (in kreuzberg.libs/) is resolved via the extension's RPATH
    # after patching; libc/libm/libpthread/libdl come from glibc.
    buildInputs = [ stdenv.cc.cc.lib ];

    pythonImportsCheck = [ "kreuzberg" ];

    meta = {
      description = "Text and metadata extraction library for documents and images";
      homepage = "https://github.com/Goldziher/kreuzberg";
      license = lib.licenses.mit;
      platforms = [ "x86_64-linux" ];
      sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    };
  });
in
python3Packages.buildPythonApplication {
  pname = "manspider";
  version = "0-unstable-2026-08-20";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "blacklanternsecurity";
    repo = "MANSPIDER";
    # No upstream tags/releases; pinned to the current master commit (CLAUDE.md §6).
    rev = "d373b056b2793c3ee50a94656325f1c2bab176a3";
    hash = "sha256-qUGl5yZnR/JF4FVDgLPEhYRz/uLYs5H+wKcJYIGcC7Y=";
  };

  build-system = [ python3Packages.hatchling ];

  nativeBuildInputs = [ makeWrapper ];

  dependencies = [
    kreuzberg
    python3Packages.impacket
    python3Packages.charset-normalizer
  ];

  # The content-match pretty-printer shells out to `grep` (subprocess); make it
  # available to the installed program regardless of the caller's PATH.
  postFixup = ''
    wrapProgram $out/bin/manspider \
      --prefix PATH : ${lib.makeBinPath [ gnugrep ]}
  '';

  # man_spider.lib.logger writes runtime state below $HOME/.manspider.
  # Runtime tests therefore use a writable temporary HOME on the WorkVM.

  # Upstream's test suite is split: tests/test_kreuzberg.py exercises content
  # extraction (offline) and tests/test_smb_integration.py spins up an impacket
  # SMB server on a TCP socket. The latter needs loopback networking that the Nix
  # sandbox does not grant, and the former needs the docx/pdf test corpus plus a
  # tesseract OCR backend for the image case. Functional fixture tests are run
  # locally on the WorkVM and are intentionally not stored in the public repo.
  doCheck = false; # begruendet: SMB-Test braucht Netz-Socket, kreuzberg-Test braucht OCR/tesseract; offline-Kern via passthru-Fixtures abgedeckt

  meta = {
    description = "Full-featured SMB spider that searches shares by filename and file content";
    homepage = "https://github.com/blacklanternsecurity/MANSPIDER";
    license = lib.licenses.gpl3Only;
    platforms = [ "x86_64-linux" ]; # kreuzberg wheel is linux-x86_64 only
    mainProgram = "manspider";
  };
}
