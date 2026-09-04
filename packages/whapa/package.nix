{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  makeWrapper,
  python3,
}:

# whapa -- WhatsApp Parser toolkit. A collection of standalone Python scripts
# under libs/ (whapa.py = msgstore.db report generator, whacipher.py =
# crypt12/14/15 decryptor, whachat/whamerge/whacloud/whagodri = chat/merge/cloud
# helpers). Upstream ships no setup.py/pyproject; the scripts import each other
# as sibling modules (whadeps, whacodes, whareader, whareport), so the whole
# libs/ tree is installed side by side and each entry point is wrapped to run
# with libs/ on PYTHONPATH -- the recuperabit pattern.
#
# Dead-disk / offline forensics on Linux
# --------------------------------------
# Nothing here needs a live Android/iOS device or Windows. Point the tools at
# files already extracted from a mounted evidence image:
#
#   * Parse an extracted msgstore.db (SQLite) into a report, print active chats:
#       whapa /mnt/evidence/.../msgstore.db -i 3
#       whapa /mnt/evidence/.../msgstore.db -m -a -r -o /case/out   # full report
#
#   * Decrypt an offline WhatsApp backup with a recovered key (no device):
#       whacipher -f /mnt/evidence/.../msgstore.db.crypt15 \
#                 -d /mnt/evidence/.../key    -o /case/msgstore.db
#     -d takes a key file or 64 hex chars; crypt12/14/15 are auto-detected.
#
# The msgstore.db parser (whapa) and the crypt decryptor (whacipher) are the
# dead-disk core and the only entry points wrapped here. The cloud/web helpers
# (whagodri = Google Drive, whacloud = iCloud) and the customtkinter GUI need
# network / a live account / a display and are intentionally not wrapped -- see
# the note below. Their sources are still installed, so they can be run manually
# if ever needed; they just are not exposed on PATH.
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "whapa";
  version = "0-unstable-2026-08-02";

  src = fetchFromGitHub {
    owner = "b16f00t";
    repo = "whapa";
    rev = "c17ca34e570411280fa2ccd3db0b08394da246b3";
    hash = "sha256-Ap/6Ix1pO0plNqNJOSG3MZrKRPwNSvaheWfOFsoYaiA=";
  };

  nativeBuildInputs = [ makeWrapper ];

  # Runtime interpreter carrying only the deps the dead-disk core imports:
  # colorama (whapa.py, optional via ImportError fallback) and pycryptodome
  # (whacipher.py, imported as Crypto). The heavy deps in doc/requirements.txt
  # (pandas/numpy/selenium/pyicloud/customtkinter) are never imported at module
  # load time -- they sit behind the GUI/cloud features, which are not wrapped.
  pythonEnv = python3.withPackages (ps: [
    ps.colorama
    ps.pycryptodome
  ]);

  installPhase = ''
    runHook preInstall

    dst="$out/libexec/whapa"
    mkdir -p "$dst"
    cp -r libs/. "$dst/"

    # Precompile deterministically so the read-only store cache is never
    # rewritten at runtime and the .pyc carry no build timestamp.
    ${lib.getExe finalAttrs.pythonEnv} -m compileall -q --invalidation-mode unchecked-hash "$dst" || true

    # Wrap the two dead-disk entry points. Each script imports its siblings by
    # bare name, so libs/ must be on PYTHONPATH.
    for prog in whapa whacipher; do
      makeWrapper ${lib.getExe finalAttrs.pythonEnv} "$out/bin/$prog" \
        --add-flags "$dst/$prog.py" \
        --prefix PYTHONPATH : "$dst"
    done

    runHook postInstall
  '';

  # whapa prints its banner + a usage table when given no mode; with a real
  # msgstore.db and -i 3 it prints the active-chats table. argparse -h proves a
  # clean start and that the sibling modules (whareader/whareport/...) imported.

  meta = {
    description = "Parse and decrypt WhatsApp msgstore.db backups and crypt12/14/15 archives";
    homepage = "https://github.com/b16f00t/whapa";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.unix;
    mainProgram = "whapa";
  };
})
