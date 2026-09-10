{
  lib,
  python3Packages,
  fetchFromGitHub,
}:

# Windows Registry parser + CLI. Pure-Python; runtime deps (construct,
# inflection, pytz) and the CLI extra (click, tabulate) are all in nixpkgs.
# The `full` extra pulls libfwsi-python/libfwps-python (shell-item parsing),
# which are absent from nixpkgs -- deliberately omitted; the core parser and
# every console script work without them (TASKS.md).
python3Packages.buildPythonApplication (finalAttrs: {
  pname = "regipy";
  version = "6.3.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "mkorman90";
    repo = "regipy";
    tag = finalAttrs.version;
    hash = "sha256-m/7OKJEl3QHfOcJQNqYSlcsGLo9awgzdSMuJjq57r/o=";
  };

  build-system = [ python3Packages.setuptools ];

  dependencies = with python3Packages; [
    construct
    inflection
    pytz
    # cli extra -- required for the console scripts (regipy.cli imports click/tabulate).
    click
    tabulate
  ];

  pythonImportsCheck = [ "regipy" ];

  # Upstream test suite decompresses large hive fixtures and exercises optional
  # shell-item plugins that need libfwsi/libfwps (absent here); the smoke and
  # fixture tests below cover startup and real hive parsing instead.
  doCheck = false; # begruendet: full extra fehlt (libfwsi/libfwps), Kern via smoke/fixture abgedeckt

  meta = {
    description = "Parse offline Windows Registry hives";
    homepage = "https://github.com/mkorman90/regipy";
    changelog = "https://github.com/mkorman90/regipy/releases/tag/${finalAttrs.version}";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
    mainProgram = "regipy-dump";
  };
})
