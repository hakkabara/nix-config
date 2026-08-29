{
  lib,
  python3Packages,
  fetchFromGitHub,
}:

# Pure Python stdlib, no external runtime deps. The optional FUSE extra depends
# on `llfuse`, which is missing from nixpkgs; it is intentionally omitted
# (TASKS.md) rather than packaging llfuse. The `vsc_mount` helper does not
# require FUSE to start.
python3Packages.buildPythonApplication (finalAttrs: {
  pname = "dfir-ntfs";
  version = "1.1.20";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "msuhanov";
    repo = "dfir_ntfs";
    tag = finalAttrs.version;
    hash = "sha256-7Ogn3oUrsdeeyQ6WdunJDY0NClzUUjL7brQt6j7IETo=";
  };

  build-system = [ python3Packages.setuptools ];

  doCheck = false; # upstream tests need network/artefacts; smoke test covers startability

  pythonImportsCheck = [ "dfir_ntfs" ];

  meta = {
    description = "NTFS/FAT parser for digital forensics and incident response";
    homepage = "https://github.com/msuhanov/dfir_ntfs";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.unix;
    mainProgram = "ntfs_parser";
  };
})
