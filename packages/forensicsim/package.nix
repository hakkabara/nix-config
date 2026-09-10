{
  lib,
  python3Packages,
  fetchFromGitHub,
  makeWrapper,
}:

# Offline parser for the IndexedDB LevelDB of Electron-based messengers
# (primarily Microsoft Teams; also Teams 2.0 / Skype). It reconstructs
# messages, contacts, meetings and reactions from the raw *.ldb / *.log files
# without a running Teams client.
#
# Dead-disk usage: mount the acquired image read-only and point the parser at
# the Teams IndexedDB LevelDB directory found under the user profile, e.g.
#   .../AppData/Roaming/Microsoft/Teams/IndexedDB/https_teams.microsoft.com_0.indexeddb.leveldb
# (Teams 2.0: .../Packages/MSTeams_*/LocalCache/Microsoft/MSTeams/EBWebView/
#             .../IndexedDB/https_teams.live.com_0.indexeddb.leveldb). Then:
#   ms_teams_parser -f <that .leveldb dir> -o messages.json
# The input directory name must end in ".leveldb" (upstream guard). Fully
# offline -- no Windows and no running Teams required.
#
# Upstream ships the CLIs as loose scripts under tools/ with no [project.scripts]
# entry points, so they are installed and wrapped by hand below. The Windows-only
# GUI-automation deps (pyautogui, pywinauto, pause) are only used by the
# tools/populate_* data-generation helpers, not by the parser, and are dropped.

let
  # Pure-Python Snappy decompressor, no dependencies. Consumed by
  # ccl_chromium_reader on the LevelDB read path. No release tag upstream.
  ccl-simplesnappy = python3Packages.buildPythonPackage {
    pname = "ccl-simplesnappy";
    version = "0.4-unstable-2024-07-30";
    pyproject = true;

    src = fetchFromGitHub {
      owner = "cclgroupltd";
      repo = "ccl_simplesnappy";
      rev = "3d085230baa8c46cf2090ebba29bf6e8eab31087";
      hash = "sha256-ssQIZyhrhttqaQjdk/DOiRwqBiKqCf9QiDN2rJ6E7+c=";
    };

    # Upstream declares readme = "README.md" but ships no README, which breaks
    # the setuptools metadata build; drop the field.
    postPatch = ''
      substituteInPlace pyproject.toml \
        --replace-fail 'readme = "README.md"' ""
    '';

    build-system = [ python3Packages.setuptools ];

    pythonImportsCheck = [ "ccl_simplesnappy" ];

    meta = {
      description = "Pure-Python Snappy decompressor with no dependencies";
      homepage = "https://github.com/cclgroupltd/ccl_simplesnappy";
      license = lib.licenses.mit;
      platforms = lib.platforms.all;
    };
  };

  # Reimplementation of Chromium data-source readers (LevelDB, IndexedDB, ...).
  # zstd/brotli are only used on the browser-cache / profile-folder paths, but
  # __init__ imports the profile-folder module top-level, so both are runtime
  # imports and must be present.
  ccl-chromium-reader = python3Packages.buildPythonPackage (finalAttrs: {
    pname = "ccl-chromium-reader";
    version = "0.3.18";
    pyproject = true;

    src = fetchFromGitHub {
      owner = "cclgroupltd";
      repo = "ccl_chromium_reader";
      tag = finalAttrs.version;
      hash = "sha256-BRplu68GTnXmMkxfX/Pbb8IFPAzotbGCknzrZJvu8s8=";
    };

    build-system = [ python3Packages.setuptools ];

    # Upstream pins zstd==1.5.7.2 and points ccl_simplesnappy at a git URL;
    # nixpkgs ships zstd 1.5.7.x (API-compatible: only decompress/Error are used)
    # and simplesnappy is provided as a dependency, so relax both.
    pythonRelaxDeps = [
      "zstd"
      "ccl_simplesnappy"
    ];

    dependencies = [
      python3Packages.brotli
      python3Packages.zstd
      ccl-simplesnappy
    ];

    pythonImportsCheck = [ "ccl_chromium_reader" ];

    meta = {
      description = "Python reimplementations of Chromium data-source readers (LevelDB, IndexedDB)";
      homepage = "https://github.com/cclgroupltd/ccl_chromium_reader";
      license = lib.licenses.mit;
      platforms = lib.platforms.all;
    };
  });
in
python3Packages.buildPythonApplication (finalAttrs: {
  pname = "forensicsim";
  version = "0.8.5";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "lxndrblz";
    repo = "forensicsim";
    tag = "v${finalAttrs.version}";
    hash = "sha256-QUJ8eDasJufZq8deRg+CYNALQajhjSV4NjaMOsa1vS4=";
  };

  # Drop the git-URL ccl_chromium_reader pin (provided as a dependency) and the
  # Windows-only GUI-automation deps that only the tools/populate_* helpers use.
  pythonRemoveDeps = [
    "ccl_chromium_reader"
    "pause"
    "pyautogui"
    "pywinauto"
  ];

  build-system = [ python3Packages.setuptools ];

  nativeBuildInputs = [ makeWrapper ];

  dependencies = [
    python3Packages.beautifulsoup4
    python3Packages.click
    python3Packages.dataclasses-json
    ccl-chromium-reader
  ];

  pythonImportsCheck = [ "forensicsim" ];

  # The CLIs live as loose scripts under tools/ (no console_scripts). Install
  # the parser scripts and wrap them so they run on the installed package.
  postInstall = ''
    install -Dm644 tools/main.py "$out/share/forensicsim/ms_teams_parser.py"
    install -Dm644 tools/dump_leveldb.py "$out/share/forensicsim/dump_leveldb.py"

    makeWrapper ${python3Packages.python.interpreter} "$out/bin/ms_teams_parser" \
      --add-flags "$out/share/forensicsim/ms_teams_parser.py" \
      --prefix PYTHONPATH : "$PYTHONPATH"
    makeWrapper ${python3Packages.python.interpreter} "$out/bin/dump_leveldb" \
      --add-flags "$out/share/forensicsim/dump_leveldb.py" \
      --prefix PYTHONPATH : "$PYTHONPATH"
  '';

  meta = {
    description = "Parse offline Microsoft Teams IndexedDB LevelDB into messages and contacts";
    homepage = "https://github.com/lxndrblz/forensicsim";
    changelog = "https://github.com/lxndrblz/forensicsim/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
    mainProgram = "ms_teams_parser";
  };
})
