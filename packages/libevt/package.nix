{
  lib,
  stdenv,
  fetchurl,
  pkg-config,
  ncurses,
  python3,
}:

# Template: nixpkgs pkgs/by-name/li/libbde/package.nix
# Same scheme applies to libvshadow (vshadowinfo) and libesedb (esedbexport, pyesedb).
stdenv.mkDerivation (finalAttrs: {
  pname = "libevt";
  version = "20260705";

  src = fetchurl {
    url = "https://github.com/libyal/libevt/releases/download/${finalAttrs.version}/libevt-alpha-${finalAttrs.version}.tar.gz";
    hash = "sha256-wUFgzY/neCQ88f5AlEaaABSg3Qjl6H+86xxM7dZWLUU=";
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
    substituteInPlace pyevt/Makefile \
      --replace-fail '$(LIBTOOL) $(AM_LIBTOOLFLAGS) $(LIBTOOLFLAGS) --mode=install' ' '
  '';

  meta = {
    description = "Library to access the Windows Event Log (EVT) format";
    homepage = "https://github.com/libyal/libevt";
    changelog = "https://github.com/libyal/libevt/blob/${finalAttrs.version}/ChangeLog";
    license = lib.licenses.lgpl3Plus;
    platforms = lib.platforms.unix;
    mainProgram = "evtexport";
  };
})
