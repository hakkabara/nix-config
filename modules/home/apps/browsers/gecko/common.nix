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

  cookieOverrideType = lib.types.submodule {
    options = {
      mode = lib.mkOption {
        type = lib.types.enum [
          "inherit"
          "extend"
          "replace"
          "none"
        ];
        default = "inherit";
        description = ''
          How this cookie layer combines with the previous layer:
          inherit keeps it unchanged, extend adds origins, replace
          replaces all inherited origins, and none removes all origins.
        '';
      };

      clearOnShutdown = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        description = ''
          Override cookie/site-data cleanup for this browser or profile.
          null inherits the previous layer.
        '';
      };

      persistentOrigins = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Cookie origins contributed by this override layer.";
      };
    };
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

  cookieCfg = cfg.privacy.cookies;

  cookieOverrides = [
    cookieCfg.firefox
    cookieCfg.floorp
  ]
  ++ lib.attrValues cookieCfg.profiles.firefox
  ++ lib.attrValues cookieCfg.profiles.floorp;

  allCookieOrigins =
    cookieCfg.common.persistentOrigins
    ++ lib.concatMap (override: override.persistentOrigins) cookieOverrides;

  isOrigin = origin: builtins.match "https?://[^/?#]+/?" origin != null;

  overrideOriginsAreMeaningful =
    override:
    lib.elem override.mode [
      "extend"
      "replace"
    ]
    || override.persistentOrigins == [ ];
in
{
  options.hakkabara.browsers.gecko = {
    firefox.enable = lib.mkEnableOption "Firefox";
    floorp.enable = lib.mkEnableOption "Floorp";

    # ============================================================
    # Shared Gecko privacy configuration
    # ============================================================

    privacy = {
      antiClutter.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Disable sponsored content, recommendations, onboarding,
          and other Mozilla/Gecko promotional UI.
        '';
      };

      remoteSearchSuggestions.enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Enable remote search-engine suggestions while typing.
          Local history, bookmarks and open-tab results are separate.
        '';
      };

      cookies = {
        # Host-wide Gecko baseline.
        common = {
          clearOnShutdown = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = ''
              Clear cookies and site storage when Gecko browsers exit.
            '';
          };

          persistentOrigins = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            example = [
              "https://example.com"
              "https://accounts.example.org"
            ];
            description = ''
              Origins whose cookies/site data may persist for all
              Gecko browsers on this host.
            '';
          };
        };

        # Browser-specific layers.
        firefox = lib.mkOption {
          type = cookieOverrideType;
          default = { };
          description = "Firefox-specific cookie policy override.";
        };

        floorp = lib.mkOption {
          type = cookieOverrideType;
          default = { };
          description = "Floorp-specific cookie policy override.";
        };

        # Optional third layer for future multi-profile setups.
        profiles = {
          firefox = lib.mkOption {
            type = lib.types.attrsOf cookieOverrideType;
            default = { };
            description = "Firefox profile-specific cookie overrides.";
          };

          floorp = lib.mkOption {
            type = lib.types.attrsOf cookieOverrideType;
            default = { };
            description = "Floorp profile-specific cookie overrides.";
          };
        };
      };
    };

    # ============================================================
    # Bookmark manager
    # ============================================================

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

    # ============================================================
    # Extensions
    # ============================================================

    extensions = {
      uBlockOrigin.enable = mkExtensionOption "uBlock Origin";
      darkReader.enable = mkExtensionOption "Dark Reader";

      tokyoNightTheme.enable = mkExtensionOption "Tokyo Night Dark Theme";

      violentmonkey.enable = mkExtensionOption "Violentmonkey userscript manager";
      bitwarden.enable = mkExtensionOption "Bitwarden browser extension";

      multiAccountContainers.enable = mkExtensionOption "Firefox Multi-Account Containers";

      consentOMatic.enable = mkExtensionOption "Consent-O-Matic";

      sponsorBlock.enable = mkExtensionOption "SponsorBlock";
      enhancerForYouTube.enable = mkExtensionOption "Enhancer for YouTube";
    };
  };

  config = lib.mkIf (cfg.firefox.enable || cfg.floorp.enable) {
    assertions = [
      {
        assertion = lib.all isOrigin allCookieOrigins;
        message = ''
          Gecko cookie persistence entries must be origins such as
          https://example.com, without paths, queries or fragments.
        '';
      }

      {
        assertion = lib.all overrideOriginsAreMeaningful cookieOverrides;
        message = ''
          Gecko cookie overrides using mode "inherit" or "none"
          must not contain persistentOrigins. Use "extend" or
          "replace" when specifying origins.
        '';
      }
    ];

    home.packages = lib.optionals managerCfg.enable [
      browserBookmarks
      firefoxBookmarksCompat
    ];
  };
}
