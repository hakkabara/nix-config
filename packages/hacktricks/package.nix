{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  mdbook,
  mdbook-tabs,
  python3,
  runCommand,
  static-web-server,
  curl,
}:

# HackTricks (German translation, branch "de") as a static mdBook site, served
# locally by modules/nixos/services/hacktricks.nix. Upstream's local setup runs
# a container that git-pulls on start; here a pinned commit is built once.
#
# Offline behaviour:
#   - hacktricks-preprocessor.py fetches the titles of external links in
#     env "prod"; env "dev" (as in upstream's container) skips that, so the
#     build needs no network.
#   - theme/ht_searcher.js loads the local /searchindex.js (built by mdbook)
#     whenever the page is served from a private host such as localhost, and
#     falls back to the bundled elasticlunr.min.js when the CDN is unreachable.
#   - The AI assistant and sponsor widgets call hacktricks.wiki and simply
#     stay empty offline.
#
# Update: point rev at a newer commit of the "de" branch, bump version to its
# date and refresh hash (nix flake prefetch github:HackTricks-wiki/hacktricks/<rev>).
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "hacktricks";
  version = "0-unstable-2026-11-21";

  src = fetchFromGitHub {
    owner = "HackTricks-wiki";
    repo = "hacktricks";
    # Branch "de" (German translation).
    rev = "8f763719bc3f0ca6988a1138b397822a975db2bc";
    hash = "sha256-Q3AjnzwZq7yPB9OXSRzVIbEDIrp5XCsGOgAWc6n0daw=";
  };

  nativeBuildInputs = [
    mdbook
    mdbook-tabs
    python3 # hacktricks-preprocessor.py (stdlib only)
  ];

  buildPhase = ''
    runHook preBuild
    export MDBOOK_PREPROCESSOR__HACKTRICKS__ENV=dev
    mdbook build --dest-dir "$TMPDIR/site"
    if [ -s hacktricks-preprocessor-error.log ]; then
      echo "--- hacktricks-preprocessor-error.log:"
      cat hacktricks-preprocessor-error.log
      exit 1
    fi
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share"
    cp -r "$TMPDIR/site" "$out/share/hacktricks"
    runHook postInstall
  '';

  # The site must be complete and searchable offline: German start page,
  # a realistic page count, the local search index and the lunr fallback.
  passthru.tests = {
    site = runCommand "hacktricks-site-test" { } ''
      set -euo pipefail
      site=${finalAttrs.finalPackage}/share/hacktricks
      test -s "$site/index.html"
      grep -q 'HackTricks lokal ausführen' "$site/index.html"
      pages=$(find "$site" -name '*.html' | wc -l)
      echo "pages: $pages"
      test "$pages" -gt 500
      test -s "$site/searchindex.js"
      grep -q 'Kerberos' "$site/searchindex.js"
      test -s "$site/elasticlunr.min.js"
      test -s "$site/theme/ht_searcher.js"
      grep -q 'src="theme/ht_searcher.js"' "$site/index.html"
      echo "PASS: German site with $pages pages and local search index"
      touch $out
    '';

    # Served as the NixOS module does: start page, a deep page, the search
    # index and a missing page must answer as expected over HTTP.
    serve =
      runCommand "hacktricks-serve-test"
        {
          nativeBuildInputs = [
            static-web-server
            curl
          ];
        }
        ''
          site=${finalAttrs.finalPackage}/share/hacktricks
          static-web-server --host 127.0.0.1 --port 3337 --root "$site" \
            --page404 "$site/404.html" --directory-listing false --log-level warn &
          pid=$!
          for _ in $(seq 50); do curl -fs -o /dev/null http://127.0.0.1:3337/ && break; sleep 0.2; done
          code() { curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:3337$1"; }
          [ "$(code /)" = 200 ]
          [ "$(code /searchindex.js)" = 200 ]
          [ "$(code /theme/ht_searcher.js)" = 200 ]
          [ "$(code /network-services-pentesting/pentesting-kerberos-88/index.html)" = 200 ]
          [ "$(code /does-not-exist.html)" = 404 ]
          curl -fs http://127.0.0.1:3337/ | grep -q 'HackTricks lokal ausführen'
          kill $pid
          echo "PASS: site served over HTTP"
          touch $out
        '';
  };

  meta = {
    description = "HackTricks pentesting wiki (German translation) as a local static site";
    homepage = "https://book.hacktricks.wiki/de/";
    # No licence file in the repository; content is free to read online.
    license = lib.licenses.unfree;
    platforms = lib.platforms.all;
  };
})
