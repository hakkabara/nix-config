{
  lib,
  stdenv,
  fetchurl,
  pkg-config,
  ncurses,
  python3,
}:

# Template: nixpkgs pkgs/by-name/li/libbde/package.nix (libyal pattern, cf. libevt).
stdenv.mkDerivation (finalAttrs: {
  pname = "libvshadow";
  version = "20260714";

  src = fetchurl {
    url = "https://github.com/libyal/libvshadow/releases/download/${finalAttrs.version}/libvshadow-alpha-${finalAttrs.version}.tar.gz";
    hash = "sha256-floET4kAl76MQB2R72EyLDH+OOPB/TrglzF01sdWm9A=";
  };

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [
    ncurses
    python3
  ];

  configureFlags = [ "--enable-python" ];

  # libyal packages install the Python bindings via libtool, which fails in the
  # Nix sandbox build (cf. libbde).
  preInstall = ''
    substituteInPlace pyvshadow/Makefile \
      --replace-fail '$(LIBTOOL) $(AM_LIBTOOLFLAGS) $(LIBTOOLFLAGS) --mode=install' ' '
  '';

  meta = {
    description = "Library to access the Volume Shadow Snapshot (VSS) format";
    homepage = "https://github.com/libyal/libvshadow";
    changelog = "https://github.com/libyal/libvshadow/blob/${finalAttrs.version}/ChangeLog";
    license = lib.licenses.lgpl3Plus;
    platforms = lib.platforms.unix;
    mainProgram = "vshadowinfo";
  };
})
