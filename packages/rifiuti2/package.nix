{
  lib,
  stdenv,
  fetchFromGitHub,
  pkg-config,
  cmake,
  glib,
  nix-update-script,
}:

# Windows Recycle Bin / $Recycle.Bin forensics parser for offline Dead-Disk
# analysis. Two binaries are installed:
#
#   rifiuti       -- parses legacy INFO2 files (Windows 95/NT/2000/XP/2003)
#   rifiuti-vista -- parses $I... index files under $Recycle.Bin (Vista and above)
#
# Dead-Disk usage (no live Windows required):
#   Mount the image: mount -o ro,loop image.dd /mnt/image
#   Parse old-style: rifiuti /mnt/image/RECYCLER/S-1-5-21-.../INFO2
#   Parse new-style: rifiuti-vista /mnt/image/\$Recycle.Bin/S-1-5-21-.../
#   Input is a read-only path on the mounted image; the tool is a pure
#   offline parser and never writes to the source filesystem.
#
# Build system: CMake (migrated from autotools in 0.8.0).
# Only external dependency: glib-2.0 >= 2.40.0.
stdenv.mkDerivation (finalAttrs: {
  pname = "rifiuti2";
  version = "0.8.2";

  src = fetchFromGitHub {
    owner = "abelcheung";
    repo = "rifiuti2";
    tag = finalAttrs.version;
    hash = "sha256-A6nS77gfr4020icyy5Z7WK3pH8VHinauhoFcJe18YRE=";
  };

  nativeBuildInputs = [
    pkg-config
    cmake
  ];

  buildInputs = [
    glib
  ];

  passthru = {

    updateScript = nix-update-script { };
  };

  meta = {
    description = "Windows Recycle Bin INFO2 and \$Recycle.Bin forensics parser";
    homepage = "https://github.com/abelcheung/rifiuti2";
    changelog = "https://github.com/abelcheung/rifiuti2/blob/${finalAttrs.version}/NEWS.md";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.unix;
    mainProgram = "rifiuti";
  };
})
