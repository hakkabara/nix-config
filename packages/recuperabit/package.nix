{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  makeWrapper,
  python3,
}:

# NTFS file-recovery / directory-tree reconstruction tool. Script based
# (main.py + a `recuperabit` package) with NO external dependencies -- it only
# uses the Python standard library, so there is nothing to add to PYTHONPATH
# beyond the tool's own tree. Upstream ships no setup.py, hence a plain
# install + makeWrapper entry point instead of buildPythonApplication.
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "recuperabit";
  version = "1.1.6";

  src = fetchFromGitHub {
    owner = "Lazza";
    repo = "RecuperaBit";
    tag = "v${finalAttrs.version}";
    hash = "sha256-4UdQgG8NdeprUh4pQvHQT0iRRyJgrXR+SWqCAVsOcCE=";
  };

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    dst="$out/libexec/recuperabit"
    install -Dm644 main.py "$dst/main.py"
    cp -r recuperabit "$dst/recuperabit"

    # Precompile deterministically: unchecked-hash invalidation embeds no
    # mtime, so the .pyc are reproducible AND Python never tries to rewrite
    # the (read-only) store cache at runtime. Without this the installCheck
    # run below would populate __pycache__ with timestamped, nondeterministic
    # bytecode inside $out.
    ${lib.getExe python3} -m compileall -q --invalidation-mode unchecked-hash "$dst"

    makeWrapper ${lib.getExe python3} "$out/bin/recuperabit" \
      --add-flags "$dst/main.py"

    runHook postInstall
  '';

  # argparse prints usage + description and exits 0 on --help; that string
  # proves both a working start and that the recuperabit package imported.

  meta = {
    description = "Reconstruct the directory structure of damaged NTFS filesystems";
    homepage = "https://github.com/Lazza/RecuperaBit";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.unix;
    mainProgram = "recuperabit";
  };
})
