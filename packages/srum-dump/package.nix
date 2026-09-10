{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  makeWrapper,
  python3,
  python3Packages,
}:

let
  # nixpkgs pins python-registry to tag 1.4, but its setup.py still hardcodes
  # '1.3.1', so the version-check hook fails on the mismatch. Until fixed
  # upstream, align the declared version with the actual value. Same source
  # tarball, only the metadata expectation is adjusted.
  pythonRegistry = python3Packages.python-registry.overrideAttrs (_: {
    version = "1.3.1";
    __intentionallyOverridingVersion = true;
  });

  # srum-dump defaults to the pure-Python dissect.esedb engine; the optional
  # pyesedb engine (--ESE_ENGINE pyesedb) is imported lazily and not needed for
  # default operation, so pyesedb is left out here.
  pythonEnv = python3.withPackages (
    ps: with ps; [
      dissect-esedb
      dissect-util
      openpyxl
      pyyaml
      pythonRegistry
      tkinter
    ]
  );
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "srum-dump";
  version = "3.2";

  src = fetchFromGitHub {
    owner = "MarkBaggett";
    repo = "srum-dump";
    tag = "v${finalAttrs.version}";
    hash = "sha256-t2nG5yAfQ25vt40Tk6pW+4eaj1pvYjNNHFz1mcplwc8=";
  };

  postPatch = ''
    # Windows-only VSS helper modules import `win32com.client` (pywin32) at top
    # level, which does not exist on Linux. Their functions (Volume Shadow Copy,
    # live file copy via WMI) are moot on NixOS; neutralize the import so the
    # core parser stays importable.
    substituteInPlace srum-dump/copy_locked.py \
      --replace-fail "import win32com.client" "win32com = None  # removed: Windows-only"
    substituteInPlace srum-dump/create_vss.py \
      --replace-fail "import win32com.client" "win32com = None  # removed: Windows-only"
  '';

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/libexec/srum-dump"
    # Python modules only, not the Windows wheel
    # (libesedb_python-*-win_amd64.whl) or build artefacts.
    cp srum-dump/*.py "$out/libexec/srum-dump/"

    makeWrapper ${pythonEnv}/bin/python3 "$out/bin/srum-dump" \
      --add-flags "$out/libexec/srum-dump/srum_dump.py"

    runHook postInstall
  '';

  meta = {
    description = "Dump the contents of the Windows SRUM database into an XLS or CSV file";
    homepage = "https://github.com/MarkBaggett/srum-dump";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.unix;
    mainProgram = "srum-dump";
  };
})
