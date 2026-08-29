{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  fetchPypi,
  makeWrapper,
  python3,
  signature-base,
}:

# LOKI -- Simple IOC Scanner (Neo23x0). Note: `loki` in nixpkgs is the C++ Loki
# library, NOT this scanner, so we build it ourselves.
#
# LOKI is not an installable Python package (no setup.py entrypoints); loki.py
# derives its data path from os.path.dirname(__file__) and expects
# `signature-base/` and `config/` beside it. We install the tree into
# $out/libexec/loki and symlink the pinned signatures next to it. Signatures are
# reproducible via the pinned signature-base package; `loki.py --update` would
# write into the read-only store and is not used (updates go through a version
# bump, not runtime).
let
  # Not in nixpkgs. Pure-Python (tzlocal/pytz only), built locally from PyPI.
  # LOKI imports it top-level in lib/lokilogger.py but only uses it for the
  # optional syslog export.
  rfc5424-logging-handler = python3.pkgs.buildPythonPackage rec {
    pname = "rfc5424-logging-handler";
    version = "1.4.3";
    pyproject = true;

    src = fetchPypi {
      inherit pname version;
      hash = "sha256-muFAc+9tdtDHMK1rbjruzoQabUE2ctKCh2wFBtwJclc=";
    };

    build-system = [ python3.pkgs.setuptools ];
    dependencies = with python3.pkgs; [
      tzlocal
      pytz
    ];

    doCheck = false; # upstream tests fetch network fixtures; pythonImportsCheck suffices
    pythonImportsCheck = [ "rfc5424logging" ];
  };

  pythonEnv = python3.withPackages (
    ps: with ps; [
      colorama
      netaddr
      psutil
      yara-python
      rfc5424-logging-handler
    ]
  );
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "loki-scanner";
  version = "0.51.0";

  src = fetchFromGitHub {
    owner = "Neo23x0";
    repo = "Loki";
    tag = "v${finalAttrs.version}";
    hash = "sha256-gvYKftmC92nZ5jRvCJ83jfXpZixTsoEtA2/woOCD/Wg=";
  };

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    dest="$out/libexec/loki"
    mkdir -p "$dest"
    cp -r loki.py loki-upgrader.py lib config plugins "$dest/"

    # LOKI expects signatures at <app_path>/signature-base.
    ln -s ${signature-base}/share/signature-base "$dest/signature-base"

    makeWrapper ${pythonEnv}/bin/python3 "$out/bin/loki" \
      --add-flags "$dest/loki.py"

    runHook postInstall
  '';

  # --help exits 0 before the scanner (and thus signature-base) is touched.
  # Collect output first, then grep: piping directly would raise SIGPIPE.

  meta = {
    description = "Simple IOC and YARA scanner for indicators of compromise";
    homepage = "https://github.com/Neo23x0/Loki";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.unix;
    mainProgram = "loki";
  };
})
