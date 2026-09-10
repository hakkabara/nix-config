{
  lib,
  stdenv,
  fetchFromGitHub,
  pkg-config,
  makeWrapper,
  libuuid,
  fuse,
}:

# VMFS3/VMFS5 forensics tooling for ESXi datastores. Upstream (glandium) is
# unmaintained (last commit 2016) and has no release tags, so we pin the HEAD
# commit as an unstable snapshot.
#
# The `vmfs-fuse` live-mount helper targets the FUSE 2 low-level API
# (fuse_lowlevel.h / fuse_reply_*). The pinned nixpkgs still ships that as
# `fuse` (2.9.9), distinct from `fuse3`, so we build it against fuse2 rather than
# porting the tree to the fuse3 low-level API. Upstream's build enables the
# vmfs-fuse subdir only when pkg-config finds `fuse`, so listing it in
# buildInputs is enough (GNUmakefile filters vmfs-fuse out otherwise).
#
# vmfs-fuse is wrapped so it finds fuse2's `fusermount` at mount time. Mounting
# needs /dev/fuse + fusermount, which the Nix sandbox lacks, so the real live
# mount is verified end-to-end in the VM acceptance test (tests/vm-acceptance.nix).
# The sandbox fixture test instead exercises the same VMFS reading path without a
# mount: `imager -x` expands the compact test image into a real (sparse) VMFS
# volume, which debugvmfs then lists and reads. `imager` (upstream `noinst`) is
# installed for this and as a genuine tool: it converts VMFS volumes to/from the
# compact VMFSIMG format for storing/shipping large images. debugvmfs, fsck.vmfs
# and vmfs-lvm stay read-only and need no FUSE. VMFS3/VMFS5 only.
stdenv.mkDerivation (finalAttrs: {
  pname = "vmfs-tools";
  version = "0-unstable-2016-01-16";

  src = fetchFromGitHub {
    owner = "glandium";
    repo = "vmfs-tools";
    rev = "4ab76ef5b074bdf06e4b518ff6d50439de05ae7f";
    hash = "sha256-JG5s4i3BMM6KUjECGXo10E3P3dDCaBrNGLPDwrkIxJM=";
  };

  nativeBuildInputs = [
    pkg-config
    makeWrapper
  ];
  buildInputs = [
    libuuid
    fuse
  ];

  # Custom, non-autotools build: ./configure only probes pkg-config deps and
  # writes a make cache, so autoreconfHook must not be used here.
  configurePhase = ''
    runHook preConfigure
    ./configure --prefix="$out"
    runHook postConfigure
  '';

  # The version string is normally derived from `git describe`, unavailable from
  # a fetchFromGitHub tarball; the build would otherwise report "v0.0.0-patched".
  # The `version` header is an optional -include; writing it here (after unpack,
  # so it is newer than the sources) supplies the real version and keeps make's
  # version target from regenerating it.
  preBuild = ''
    printf '#define VERSION "%s"\n' "${finalAttrs.version}" > version
  '';

  # The upstream `install` target also builds man pages, which requires feeding
  # a hardcoded docbook.sourceforge.net URL to `xsltproc --nonet` — impossible
  # offline without patching the source. Install the binaries directly instead;
  # the man page sources remain available as .txt in the source tree.
  installPhase = ''
    runHook preInstall
    install -Dm755 -t "$out/bin" \
      debugvmfs/debugvmfs \
      fsck.vmfs/fsck.vmfs \
      vmfs-lvm/vmfs-lvm \
      vmfs-fuse/vmfs-fuse \
      imager/imager
    runHook postInstall
  '';

  # vmfs-fuse execs `fusermount` (fuse2) from PATH at mount time; put it on PATH
  # so a mount works without the user adding fuse to their systemPackages.
  postInstall = ''
    wrapProgram "$out/bin/vmfs-fuse" \
      --prefix PATH : ${lib.makeBinPath [ fuse ]}
  '';

  # debugvmfs has no dedicated --version flag, but any unrecognised argument
  # makes it print "debugvmfs <version>" before its usage banner, which is
  # enough for versionCheckHook to confirm the version string.

  meta = {
    description = "Tools to access VMFS (VMware ESXi) filesystems";
    homepage = "https://github.com/glandium/vmfs-tools";
    license = lib.licenses.gpl2Plus;
    platforms = lib.platforms.linux;
    mainProgram = "debugvmfs";
  };
})
