{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  perl,
  perlPackages,
}:

# DeXRAY.pl decrypts AV quarantine files (McAfee BUP, Symantec VBN, Defender,
# Kaspersky, ...). Pure Perl, no autoPatchelf needed.
#
# Upstream (CLAUDE.md §4/§8): https://hexacorn.com/d/DeXRAY.pl has no version in
# its path, so a fetchurl would break on every upstream update and cannot be
# pinned reproducibly. The file is therefore mirrored once into the repo as
# DeXRAY-<sync-date>.pl.
#
#   Source:     https://hexacorn.com/d/DeXRAY.pl
#   Sync date:  2025-12-03  (upstream Last-Modified: Wed, 03 Dec 2025 20:59:50 GMT)
#   Version per startup banner: dexray v2.37 (the file's header comment still
#   says 2.36; the banner is authoritative)
#
# To update: re-fetch, store under a new date, bump src/version/mainProgram date
# -- do not overwrite the existing file.
let
  perlDeps = [
    perlPackages.CryptRC4
    perlPackages.DigestCRC
    perlPackages.CryptBlowfish
    perlPackages.ArchiveZip
    perlPackages.CompressRawZlib
    perlPackages.OLEStorage_Lite
  ];
in
stdenvNoCC.mkDerivation (_finalAttrs: {
  pname = "dexray";
  version = "2.37-unstable-2025-12-03";

  src = fetchurl {
    url = "https://hexacorn.com/d/DeXRAY.pl";
    hash = "sha256-+lZqaPNktvMafve5A7rKSJIR2ZFiDz8AANdeRkBWYHg=";
  };

  # src is a single file, no unpack phase.
  dontUnpack = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/{bin,share/dexray}
    install -Dm644 $src $out/share/dexray/DeXRAY.pl

    makeWrapper ${perl}/bin/perl $out/bin/dexray \
      --add-flags "$out/share/dexray/DeXRAY.pl" \
      --set PERL5LIB ${perlPackages.makeFullPerlPath perlDeps}

    runHook postInstall
  '';

  meta = {
    description = "Decryptor for antivirus quarantine files (McAfee BUP, Symantec VBN, Defender, and more)";
    homepage = "https://hexacorn.com/d/DeXRAY.pl";
    license = lib.licenses.unfree; # no explicit OSS license in the script; mirroring cleared
    platforms = lib.platforms.unix;
    mainProgram = "dexray";
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
  };
})
