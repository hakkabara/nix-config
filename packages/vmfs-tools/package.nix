{
  lib,
  stdenv,
  fetchFromGitHub,
  pkg-config,
  libuuid,
}:

# VMFS3/VMFS5 forensics tooling for ESXi datastores. Upstream (glandium) is
# unmaintained (last commit 2016) and has no release tags, so we pin the HEAD
# commit as an unstable snapshot.
#
# No `vmfs-fuse`: the live-mount helper targets the FUSE 2 low-level API
# (fuse_lowlevel.h / fuse_reply_*). nixpkgs removed fuse2 as end-of-life
# (`fuse` is FUSE 3 since the 2026-11 pin, and nixpkgs dropped its own
# vmfs-tools for the same reason), so vmfs-fuse can no longer be built without
# porting it to the fuse3 low-level API. Upstream's build enables the vmfs-fuse
# subdir only when pkg-config finds `fuse`; without it the GNUmakefile filters
# vmfs-fuse out and builds the remaining tools.
#
# What remains works without a mount and reads the same VMFS on-disk structures:
# debugvmfs lists and reads files from a volume, fsck.vmfs checks it, vmfs-lvm
# inspects the LVM layer. `imager` (upstream `noinst`) is installed as a genuine
# tool: it converts VMFS volumes to/from the compact VMFSIMG format for
# storing/shipping large images. All are read-only. VMFS3/VMFS5 only.
stdenv.mkDerivation (finalAttrs: {
  pname = "vmfs-tools";
  version = "0-unstable-2016-01-16";

  src = fetchFromGitHub {
    owner = "glandium";
    repo = "vmfs-tools";
    rev = "4ab76ef5b074bdf06e4b518ff6d50439de05ae7f";
    hash = "sha256-JG5s4i3BMM6KUjECGXo10E3P3dDCaBrNGLPDwrkIxJM=";
  };

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ libuuid ];

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
      imager/imager
    runHook postInstall
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
