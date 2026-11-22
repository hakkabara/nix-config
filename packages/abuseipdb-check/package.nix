{
  lib,
  stdenvNoCC,
  makeWrapper,
  bash,
  bats,
  coreutils,
  curl,
  gawk,
  gnugrep,
  gnused,
  jq,
}:

# Read-only AbuseIPDB APIv2 reputation check for IP lists (own tool, vendored
# in src/: the script, its README and the offline bats suite with a mocked
# curl; the live smoke test and any local key or IP files are not included).
#
# Keys: the tool reads ABUSEIPDB_API_KEY (comma-separated for rotation). The
# wrapper additionally fills it from ABUSEIPDB_API_KEY_FILE (one key per line
# or comma-separated), so a sops-nix secret can feed it without the key ever
# appearing on a command line or in the environment of the calling shell.
let
  runtimePath = lib.makeBinPath [
    coreutils
    curl
    gawk
    gnugrep
    gnused
    jq
  ];
in
stdenvNoCC.mkDerivation {
  pname = "abuseipdb-check";
  version = "0-unstable-2026-11-22";

  src = ./src;

  # The sandbox has no /usr/bin/env, and the suite runs the script and the
  # curl mocks directly, so their shebangs must point into the store. The
  # scaffold test pins the shebang to /usr/bin/env or /bin/bash; it also
  # accepts the patched store bash here, the check itself (a bash shebang)
  # stays.
  postPatch = ''
    patchShebangs abuseipdb-check tests
    # Several tests write throwaway fake-curl scripts via heredoc at run time;
    # patchShebangs only sees first lines, so point those at bash too.
    sed -i 's|#!/usr/bin/env bash|#!${lib.getExe bash}|' tests/*.bats
    substituteInPlace tests/00-scaffold.bats \
      --replace-fail '|| [[ "''${output}" == "#!/bin/bash" ]]' \
        '|| [[ "''${output}" == "#!/bin/bash" ]] || [[ "''${output}" == "#!/nix/store/"*"/bin/bash" ]]'
  '';

  nativeBuildInputs = [ makeWrapper ];
  buildInputs = [ bash ];

  # The offline suite: every request goes to tests/mocks/curl with fixtures.
  doCheck = true;
  # curl too: main checks `command -v curl jq` before it uses the mock.
  nativeCheckInputs = [
    bats
    curl
    jq
  ];
  checkPhase = ''
    runHook preCheck
    export HOME="$TMPDIR/home"
    bats tests/
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 abuseipdb-check "$out/libexec/abuseipdb-check/abuseipdb-check"
    # The default cache lives next to the script (<tool-dir>/data/cache), which
    # is read-only in the store. Default to the XDG cache instead; --cache-dir
    # and the config's cache_dir still take precedence. Patched after the
    # suite, which asserts the upstream default.
    substituteInPlace "$out/libexec/abuseipdb-check/abuseipdb-check" \
      --replace-fail 'printf '"'"'%s\n'"'"' "''${tool_dir}/data/cache"' \
        'printf '"'"'%s\n'"'"' "''${XDG_CACHE_HOME:-''${HOME}/.cache}/abuseipdb"' \
      --replace-fail 'Cache-Verzeichnis (Standard: <tool-dir>/data/cache)' \
        'Cache-Verzeichnis (Standard: ~/.cache/abuseipdb)'
    install -Dm644 README.md "$out/share/doc/abuseipdb-check/README.md"
    makeWrapper "$out/libexec/abuseipdb-check/abuseipdb-check" "$out/bin/abuseipdb-check" \
      --prefix PATH : ${runtimePath} \
      --run 'if [ -z "''${ABUSEIPDB_API_KEY:-}" ] && [ -r "''${ABUSEIPDB_API_KEY_FILE:-}" ]; then ABUSEIPDB_API_KEY="$(grep -v "^[[:space:]]*$" "$ABUSEIPDB_API_KEY_FILE" | tr -d " \t\r" | paste -sd, -)"; export ABUSEIPDB_API_KEY; fi'
    runHook postInstall
  '';

  # No --version flag; --help must render the usage text.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    HOME="$TMPDIR/home" $out/bin/abuseipdb-check --help | grep -q "VERWENDUNG:"
    runHook postInstallCheck
  '';

  meta = {
    description = "Read-only AbuseIPDB reputation check for IP lists with key rotation and cache";
    license = lib.licenses.unfree; # own tool, no licence chosen yet
    platforms = lib.platforms.unix;
    mainProgram = "abuseipdb-check";
  };
}
