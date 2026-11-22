{
  lib,
  rustPlatform,
  fetchCrate,
  runCommand,
  mdbook,
}:

# mdBook preprocessor rendering {{#tabs}} / {{#tab name="..."}} blocks as
# tabbed content. Needed to build HackTricks (packages/hacktricks).
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "mdbook-tabs";
  version = "1.0.6";

  src = fetchCrate {
    inherit (finalAttrs) pname version;
    hash = "sha256-EzY0zAYic3KM4UHLwzsgReoVH4wEFr48N970mLonxPk=";
  };

  cargoHash = "sha256-px64VfOgC0m+qQ5G6kiZJjqlQzZFfjPD/CuB9yHBwfg=";

  # mdBook asks every preprocessor whether it supports a renderer; html must
  # be accepted (exit 0).
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    $out/bin/mdbook-tabs supports html
    runHook postInstallCheck
  '';

  # End to end: a two-tab chapter rendered by mdbook must contain both tabs.
  passthru.tests.render =
    runCommand "mdbook-tabs-render-test"
      {
        nativeBuildInputs = [
          mdbook
          finalAttrs.finalPackage
        ];
      }
      ''
        mkdir -p book/src
        cat > book/book.toml <<'EOF'
        [book]
        title = "tabs test"
        [preprocessor.tabs]
        EOF
        printf '# Summary\n\n- [Chapter](chapter.md)\n' > book/src/SUMMARY.md
        cat > book/src/chapter.md <<'EOF'
        # Chapter

        {{#tabs }}
        {{#tab name="Linux" }}
        linux-marker
        {{#endtab }}
        {{#tab name="Windows" }}
        windows-marker
        {{#endtab }}
        {{#endtabs }}
        EOF
        mdbook build book
        html=book/book/chapter.html
        grep -q 'class="mdbook-tabs-container"' "$html"
        grep -q 'data-tabname="Linux"' "$html"
        grep -q 'data-tabname="Windows"' "$html"
        grep -q 'windows-marker' "$html"
        echo "PASS: both tabs rendered"
        touch $out
      '';

  meta = {
    description = "mdBook preprocessor for rendering content in tabs";
    homepage = "https://mdbook-plugins.rustforweb.org/";
    changelog = "https://github.com/RustForWeb/mdbook-plugins/releases";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    mainProgram = "mdbook-tabs";
  };
})
