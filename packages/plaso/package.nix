{
  lib,
  stdenvNoCC,
}:

# plaso (log2timeline) -- super timelining for DFIR.
#
# Packaging decision (explicit user decision, see CLAUDE.md task): this is a
# thin DOCKER WRAPPER, not a native build. A native plaso needs ~20 libyal
# Python bindings plus dfvfs/dfwinreg, none of which are in nixpkgs; packaging
# all of them is out of scope. Instead we ship shell wrappers around the
# official upstream image.
#
# Runtime requirement: docker must be available on PATH at run time. It is a
# system service (modules/dfir.nix enables virtualisation.docker), so the
# wrapper deliberately resolves `docker` from PATH and does NOT hardcode a
# store path to it.
#
# The build itself is pure: it only writes shell scripts. No `docker pull`
# happens at build time -- the image is fetched by docker on first run.
let
  # Official upstream image, pinned by digest for reproducibility.
  # Digest corresponds to tag 20260720 (plaso uses calendar versioning).
  imageTag = "20260720";
  imageDigest = "sha256:a8d42e64dcd3af2dffed8ddb25d34f34def69b672eec97ea9af62885c9332950";
  image = "log2timeline/plaso@${imageDigest}";

  # Upstream CLI tools (the .py suffix is the real program name inside the
  # image). The wrapper name drops the suffix for ergonomics.
  tools = [
    "log2timeline"
    "psort"
    "pinfo"
  ];

  # `-v "$PWD":/data -w /data` mounts the working directory so relative paths
  # given on the command line resolve the same way inside the container.
  mkWrapper = tool: ''
    cat > "$out/bin/${tool}" <<EOF
    #!/bin/sh
    # plaso ${tool} -- runs the pinned upstream docker image.
    # docker is a runtime requirement, resolved from PATH.
    exec docker run --rm -v "\$PWD":/data -w /data ${image} ${tool}.py "\$@"
    EOF
    chmod +x "$out/bin/${tool}"
  '';
in
stdenvNoCC.mkDerivation (_finalAttrs: {
  pname = "plaso";
  version = imageTag;

  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin"
    ${lib.concatMapStringsSep "\n" mkWrapper tools}
    runHook postInstall
  '';

  meta = {
    description = "Super timelining tool for extracting events from many artifacts";
    homepage = "https://github.com/log2timeline/plaso";
    license = lib.licenses.asl20;
    platforms = lib.platforms.linux;
    mainProgram = "log2timeline";
  };
})
