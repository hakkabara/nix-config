{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hakkabara.browsers.gecko;
  managerCfg = cfg.bookmarks.manager;

  mkExtensionOption =
    description:
    lib.mkOption {
      type = lib.types.bool;
      default = false;
      inherit description;
    };

  mkBookmarkManager =
    name:
    pkgs.writeShellApplication {
      inherit name;

      runtimeInputs = [
        pkgs.sops
        pkgs.python3
      ];

      text = ''
        export BROWSER_BOOKMARK_PROGRAM_NAME=${lib.escapeShellArg name}
        export BROWSER_BOOKMARK_REPO_ROOT=${lib.escapeShellArg managerCfg.repositoryRoot}
        export BROWSER_BOOKMARK_SOURCE=${lib.escapeShellArg managerCfg.sourceFile}
        export BROWSER_BOOKMARK_AGE_KEY_FILE=${lib.escapeShellArg managerCfg.ageKeyFile}
        export BROWSER_BOOKMARK_DOCUMENT_TITLE=${lib.escapeShellArg managerCfg.documentTitle}

        exec python3 ${../scripts/browser-bookmarks.py} "$@"
      '';
    };

  browserBookmarks = mkBookmarkManager "browser-bookmarks";

  # Compatibility alias for the previous command name.
  firefoxBookmarksCompat = mkBookmarkManager "fbm";
in
{
  options.hakkabara.browsers.gecko = {
    firefox.enable = lib.mkEnableOption "Firefox";
    floorp.enable = lib.mkEnableOption "Floorp";

    bookmarks.manager = {
      enable = lib.mkEnableOption "SOPS-encrypted browser bookmark manager";

      repositoryRoot = lib.mkOption {
        type = lib.types.str;
        default = "${config.home.homeDirectory}/nix-config";
        description = "Checkout containing the encrypted bookmark source.";
      };

      sourceFile = lib.mkOption {
        type = lib.types.str;
        default = "secrets/browser-bookmarks";
        description = "Encrypted bookmark source relative to repositoryRoot.";
      };

      ageKeyFile = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/sops-nix/key.txt";
        description = "Age identity used for bookmark decryption.";
      };

      documentTitle = lib.mkOption {
        type = lib.types.str;
        default = "Browser Bookmarks";
        description = "Title written to the canonical Netscape bookmark document.";
      };
    };

    extensions = {
      uBlockOrigin.enable = mkExtensionOption "uBlock Origin";

      darkReader.enable = mkExtensionOption "Dark Reader";

      violentmonkey.enable = mkExtensionOption "Violentmonkey userscript manager";
      bitwarden.enable = mkExtensionOption "Bitwarden browser extension";

      multiAccountContainers.enable = mkExtensionOption "Firefox Multi-Account Containers";

      consentOMatic.enable = mkExtensionOption "Consent-O-Matic";

      sponsorBlock.enable = mkExtensionOption "SponsorBlock";

      enhancerForYouTube.enable = mkExtensionOption "Enhancer for YouTube";
    };
  };

  config = lib.mkIf (cfg.firefox.enable || cfg.floorp.enable) {
    home.packages = lib.optionals managerCfg.enable [
      browserBookmarks
      firefoxBookmarksCompat
    ];
  };
}
