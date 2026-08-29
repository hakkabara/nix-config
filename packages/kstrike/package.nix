{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  makeWrapper,
  python3,
  libesedb,
}:

# Single-file Python tool. Its only external dependency is `pyesedb`, the Python
# bindings built by our libesedb (Lane C4) with --enable-python into
# lib/${python3.sitePackages}. The wrapper adds that path to PYTHONPATH so
# `import pyesedb` resolves at runtime.
stdenvNoCC.mkDerivation (_finalAttrs: {
  pname = "kstrike";
  version = "0-unstable-2024-01-09";

  src = fetchFromGitHub {
    owner = "brimorlabs";
    repo = "KStrike";
    rev = "daf2070c95a2e1fe17b935b9e03af947a197b785";
    hash = "sha256-VvbCaE7qC6MwmeQIPa4/W4RPKXOVWX9LTfbbtQ+WjAc=";
  };

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    install -Dm644 KStrike.py "$out/libexec/kstrike/KStrike.py"
    makeWrapper ${lib.getExe python3} "$out/bin/kstrike" \
      --add-flags "$out/libexec/kstrike/KStrike.py" \
      --prefix PYTHONPATH : "${libesedb}/${python3.sitePackages}"

    runHook postInstall
  '';

  # No --version/--help. With no argument KStrike prints banner, version and
  # usage to stderr and exits 0, which also proves the pyesedb import succeeded.

  meta = {
    description = "Parser for on-disk User Access Logging (SUM) databases on Windows Server";
    homepage = "https://github.com/brimorlabs/KStrike";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.unix;
    mainProgram = "kstrike";
  };
})
