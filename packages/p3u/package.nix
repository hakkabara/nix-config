{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  makeWrapper,
  python3,
  openssl,
}:

let
  # python3.withPackages builds an interpreter that has multipart on sys.path.
  # multipart replaces the removed-in-3.13 `cgi` module for multipart/form-data
  # parsing; the API is compatible: part.filename and part.file carry the same
  # semantics as cgi.FieldStorage fields.
  pythonEnv = python3.withPackages (ps: [ ps.multipart ]);
in

# p3u -- Python 3 simple HTTP upload/download server for pentests.
# Starts an HTTP(S) server that serves directory listings with upload form,
# allowing fast file transfer during engagements. Optional Basic-Auth (-a
# user:pass) and SSL (-c cert.pem). Certificate generation via -g calls
# `openssl req -x509 ...` as a subprocess -- openssl is therefore injected
# into PATH at runtime via makeWrapper. All other SSL/TLS ops use Python
# stdlib ssl; no third-party Python deps are needed.
#
# Typical use (LIVE network tool, not dead-disk):
#   p3u -l 0.0.0.0 -p 8080              # plain HTTP, serve cwd
#   p3u -g && p3u -l 0.0.0.0 -p 443 -c server.pem   # generate cert, then HTTPS
#   p3u -l 0.0.0.0 -p 8080 -a admin:secret          # with Basic-Auth
stdenvNoCC.mkDerivation {
  pname = "p3u";
  version = "0-unstable-2025-01-29";

  src = fetchFromGitHub {
    owner = "cmprmsd";
    repo = "p3u";
    rev = "5953fc12850e3f1f915f360eb35d6f7f82a7d490";
    hash = "sha256-ij8I3nnUYg7MhoD4q9wM4qY7ruSMaiUIQDc+xFKHfjM=";
  };

  nativeBuildInputs = [
    makeWrapper
    pythonEnv
  ];

  # `cgi` was removed in Python 3.13. Replace it with the `multipart` library,
  # which provides a compatible API (parse_form_data returns a (forms, files)
  # pair; files.get("file").filename and .file mirror cgi.FieldStorage fields).
  # The patch logic lives in fix-cgi-py313.py to avoid Nix-keyword conflicts
  # ("in", "let") inside multi-line string literals.
  patchPhase = ''
    runHook prePatch
    python3 ${./fix-cgi-py313.py}
    runHook postPatch
  '';

  installPhase = ''
    runHook preInstall

    install -Dm644 p3u.py "$out/libexec/p3u/p3u.py"

    # Precompile deterministically: no mtime in .pyc, store stays read-only at
    # runtime, bytecode is reproducible.
    ${lib.getExe pythonEnv} -m compileall -q --invalidation-mode unchecked-hash "$out/libexec/p3u"

    # openssl is only needed for -g (certificate generation); inject it into
    # PATH rather than wrapping the Python env, since there are no Python deps.
    makeWrapper ${lib.getExe pythonEnv} "$out/bin/p3u" \
      --add-flags "$out/libexec/p3u/p3u.py" \
      --prefix PATH : ${lib.makeBinPath [ openssl ]}

    runHook postInstall
  '';

  # Functional validation is intentionally performed locally on the WorkVM.
  # In particular, the Python >=3.13 multipart replacement must be tested with
  # a real HTTP multipart upload rather than relying only on -h output.

  meta = {
    description = "Simple HTTP upload/download server for pentests with optional SSL and Basic-Auth";
    homepage = "https://github.com/cmprmsd/p3u";
    license = lib.licenses.unfree; # no LICENSE file in upstream repo; no OSS license declared
    platforms = lib.platforms.unix;
    mainProgram = "p3u";
  };
}
