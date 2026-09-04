{
  lib,
  stdenvNoCC,
  fetchPypi,
  makeWrapper,
  python3,
  python3Packages,
  nix-update-script,
}:

# RegRip**py** -- a modern Python-3 alternative to RegRipper. Reads Windows
# registry hives offline (dead-disk) via William Ballenthin's python-registry
# and runs one of ~40 forensic plugins (`regrippy -l` lists them).
#
# Why this package exists even though nixpkgs already ships regrippy 2.0.2:
# on the pinned nixos-unstable the nixpkgs build is broken at *runtime* for two
# independent reasons, so `nix run nixpkgs#regrippy` never does useful work:
#
#   1. python-registry mismatch: nixpkgs pins python-registry to tag 1.4, but
#      that project's setup.py still hardcodes '1.3.1', so the buildPython
#      version-check aborts with "The 'python-registry' derivation has version
#      '1.4' but .dist-info/METADATA specifies version '1.3.1'." -> regrippy
#      never even imports. Fixed here by overriding python-registry's declared
#      version to 1.3.1 (same tarball), the fix already proven in this repo for
#      srum-dump (see pkgs/srum-dump/package.nix).
#
#   2. argv[0] plugin dispatch: upstream's regrip.py selects the plugin from a
#      positional argument ONLY when argv[0] is literally "regrip.py"; under any
#      other name it treats the program name itself as the plugin (the reg_<x>
#      symlink mechanism). The nixpkgs recipe renames the entry point to
#      "regrippy", and buildPythonApplication's wrapper additionally hardcodes
#      sys.argv[0] to the wrapper path, so `regrippy <plugin>` is rejected with
#      "unrecognized arguments: <plugin>" and the reg_<plugin> console scripts
#      die on `from regrip import main` (regrip is not an importable module).
#      Fixed here by wrapping the real regrip.py with --argv0 regrip.py, which
#      restores the positional-plugin code path.
#
# Dead-disk / offline usage against a mounted image (regrippy takes explicit
# hive paths or a --root pointing at the C:\ folder):
#   regrippy -y /mnt/img/Windows/System32/config/SYSTEM services
#   regrippy -o /mnt/img/Windows/System32/config/SOFTWARE uninstall
#   regrippy -n /mnt/img/Users/alice/NTUSER.DAT typedurls
#   regrippy -u /mnt/img/Users/alice/AppData/Local/Microsoft/Windows/UsrClass.dat regtime
#   regrippy --all-user-hives -r /mnt/img userassist   # every user's NTUSER.DAT
#   regrippy -r /mnt/img --backups services            # also RegBack/ copies
# Note on dirty hives: regrippy opens the raw hive as-is and does NOT replay the
# transaction logs (*.LOG1/*.LOG2). For a hive that was not cleanly unmounted,
# flush/replay the logs first (e.g. with regipy's registry-transaction-logs or
# hivexregedit) before running regrippy, otherwise recent writes may be missing.

let
  # nixpkgs pins python-registry to tag 1.4, but its setup.py still hardcodes
  # '1.3.1', so the version-check hook fails on the mismatch and regrippy never
  # imports. Align the declared version with the actual metadata value. Same
  # source tarball, only the version expectation is adjusted. (Same fix as
  # pkgs/srum-dump/package.nix; upstream python-registry fix candidate.)
  pythonRegistry = python3Packages.python-registry.overrideAttrs (_: {
    version = "1.3.1";
    __intentionallyOverridingVersion = true;
  });

  pythonEnv = python3.withPackages (
    ps: with ps; [
      importlib-resources
      pythonRegistry
    ]
  );
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "regrippy";
  version = "2.0.2";

  src = fetchPypi {
    inherit (finalAttrs) pname version;
    # Hash matches the nixpkgs regrippy recipe (same PyPI sdist).
    hash = "sha256-43Wh5iQE1ihD8aGxDmmwKDkPeMfySP0mdk0XhrVefyc=";
  };

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    # Ship the regrippy package (plugins live here, discovered via
    # importlib_resources) and the regrip.py launcher unchanged. Placing the
    # package next to regrip.py keeps `from regrippy import BasePlugin` and
    # `importlib_resources.files("regrippy.plugins")` resolvable.
    mkdir -p "$out/libexec/regrippy"
    cp -r regrippy "$out/libexec/regrippy/regrippy"
    cp regrip.py "$out/libexec/regrippy/regrip.py"

    # regrip.py must run as an executable script whose shebang points at the
    # withPackages env. Launching ${pythonEnv}/bin/python3 with --argv0 regrip.py
    # would detach the interpreter from the env's site-packages (python derives
    # its prefix from argv[0]) and importlib_resources/python-registry would
    # vanish; pointing the shebang at the env keeps sys.executable in the env
    # regardless of argv[0].
    substituteInPlace "$out/libexec/regrippy/regrip.py" \
      --replace-fail "#!/usr/bin/env python3" "#!${pythonEnv}/bin/python3"
    chmod +x "$out/libexec/regrippy/regrip.py"

    # --argv0 regrip.py is load-bearing: regrip.py only accepts a positional
    # plugin name (e.g. `regrippy services`) when basename(argv[0]) == regrip.py;
    # under any other name it dispatches on the program name instead and rejects
    # the positional argument. Wrap the script itself (not python3), so argv[0]
    # is regrip.py but sys.executable stays the env python from the shebang.
    # --prefix (not --set): the withPackages env supplies importlib_resources /
    # python-registry via its own site-packages; only prepend the launcher dir so
    # `import regrippy` and the regrip module resolve, without shadowing the env.
    makeWrapper "$out/libexec/regrippy/regrip.py" "$out/bin/regrippy" \
      --argv0 regrip.py \
      --prefix PYTHONPATH : "$out/libexec/regrippy" \
      --set PYTHONDONTWRITEBYTECODE 1

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Modern Python-3 alternative to RegRipper for offline Windows registry hives";
    homepage = "https://github.com/airbus-cert/regrippy";
    license = lib.licenses.asl20;
    platforms = lib.platforms.unix;
    mainProgram = "regrippy";
  };
})
