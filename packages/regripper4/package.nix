{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  makeWrapper,
  perl,
  perlPackages,
}:

# RegRipper 4.0 (CLI: rip.pl). Pure Perl, no autoPatchelf needed.
#
# rip.pl uses `FindBin qw($RealBin)` to load time.pl, rr_helper.pl and the
# plugins/ directory relative to $RealBin. Copying the whole repo into
# $out/share/regripper4 and wrapping rip.pl from there makes $RealBin resolve
# to that directory, so all helpers and plugins are found. The Windows shebang
# (#! c:\perl\bin\perl.exe) is irrelevant because the wrapper invokes
# ${perl}/bin/perl explicitly.
let
  perlDeps = [
    perlPackages.ParseWin32Registry
  ];
in
stdenvNoCC.mkDerivation (_finalAttrs: {
  pname = "regripper4";
  version = "0-unstable-2025-12-10";

  src = fetchFromGitHub {
    owner = "keydet89";
    repo = "RegRipper4.0";
    rev = "f925c0965db202eed46071b3e68f6d3a49b41a31";
    hash = "sha256-HOdsNcvh8CDi7quIE9uWvk1si6xIod9SMHmyOrDOILo=";
  };

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/{bin,share}

    # Drop Windows binaries; nothing executable should land in the store.
    rm -f *.exe *.dll *.ico

    cp -aR . "$out/share/regripper4/"

    makeWrapper ${perl}/bin/perl $out/bin/regripper4 \
      --add-flags "$out/share/regripper4/rip.pl" \
      --set PERL5LIB ${perlPackages.makeFullPerlPath perlDeps}

    runHook postInstall
  '';

  meta = {
    description = "Windows Registry hive parser driven by per-hive plugins (RegRipper 4.0 CLI)";
    homepage = "https://github.com/keydet89/RegRipper4.0";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    mainProgram = "regripper4";
  };
})
