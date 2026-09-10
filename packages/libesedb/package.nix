{
  lib,
  stdenv,
  fetchurl,
  pkg-config,
  ncurses,
  python3,
}:

# Template: nixpkgs pkgs/by-name/li/libbde/package.nix (libyal pattern, cf. libevt).
# Unlike libevt/libvshadow, the pyesedb bindings are actually needed here
# (srum-dump, Lane C6), so the built pyesedb.so is installed into site-packages
# instead of merely dropping the libtool install.
stdenv.mkDerivation (finalAttrs: {
  pname = "libesedb";
  version = "20260704";

  src = fetchurl {
    url = "https://github.com/libyal/libesedb/releases/download/${finalAttrs.version}/libesedb-experimental-${finalAttrs.version}.tar.gz";
    hash = "sha256-ePXkzRG1UeZz2ycKnUCr88jshSO5GTmpJRyoDuWoO9E=";
  };

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [
    ncurses
    python3
  ];

  configureFlags = [ "--enable-python" ];

  # automake sets pyexecdir to the absolute (read-only) store path of the python3
  # package, so `make install` drops the bindings into $out/ via the DESTDIR fallback
  # instead of site-packages, where pyesedb is not importable. Move the finished,
  # correctly named .so to a location on PYTHONPATH (srum-dump, Lane C6, imports
  # pyesedb). The .la is irrelevant for the import.
  postInstall = ''
    install -Dm555 "$out"/pyesedb.cpython-*.so \
      -t "$out/${python3.sitePackages}"
    rm -f "$out"/pyesedb.cpython-*.so "$out"/pyesedb.la
  '';

  meta = {
    description = "Library to access the Extensible Storage Engine (ESE) Database File (EDB) format";
    homepage = "https://github.com/libyal/libesedb";
    changelog = "https://github.com/libyal/libesedb/blob/${finalAttrs.version}/ChangeLog";
    license = lib.licenses.lgpl3Plus;
    platforms = lib.platforms.unix;
    mainProgram = "esedbexport";
  };
})
