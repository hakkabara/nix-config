{
  lib,
  cfg,
  browser,
  profile ? null,
}:

let
  validBrowsers = [
    "firefox"
    "floorp"
  ];

  checkedBrowser =
    if lib.elem browser validBrowsers then
      browser
    else
      throw "Unsupported Gecko browser for shared.nix: ${browser}";

  extensionSettings = import ./extensions.nix {
    inherit lib;
    cfg = cfg.extensions;
  };

  mkFirefoxExtensionAccessPolicy =
    access:
    lib.optionalAttrs (access.runtimeBlockedHosts != [ ]) {
      runtime_blocked_hosts = access.runtimeBlockedHosts;
    }
    // lib.optionalAttrs (access.runtimeAllowedHosts != [ ]) {
      runtime_allowed_hosts = access.runtimeAllowedHosts;
    }
    // lib.optionalAttrs (access.blockedPermissions != [ ]) {
      blocked_permissions = access.blockedPermissions;
    }
    // lib.optionalAttrs (access.allowedPermissions != [ ]) {
      allowed_permissions = access.allowedPermissions;
    };

  # runtime_*_hosts and permission blocking were introduced in
  # Firefox 153. Floorp currently uses Gecko 152, so never emit
  # these fields for Floorp until its Gecko base catches up.
  firefoxRuntimeExtensionSettings = lib.optionalAttrs (checkedBrowser == "firefox") (
    (lib.optionalAttrs cfg.extensions.sponsorBlock.enable {
      "sponsorBlocker@ajay.app" = mkFirefoxExtensionAccessPolicy cfg.extensions.sponsorBlock.firefox;
    })
    // (lib.optionalAttrs cfg.extensions.enhancerForYouTube.enable {
      "enhancerforyoutube@maximerf.addons.mozilla.org" =
        mkFirefoxExtensionAccessPolicy cfg.extensions.enhancerForYouTube.firefox;
    })
    // (lib.optionalAttrs cfg.extensions.violentmonkey.enable {
      "{aecec67f-0d10-4fa7-b7c7-609a2db280cf}" =
        mkFirefoxExtensionAccessPolicy cfg.extensions.violentmonkey.firefox;
    })
  );

  effectiveExtensionSettings = lib.recursiveUpdate extensionSettings firefoxRuntimeExtensionSettings;

  firefoxSyncCfg = cfg.sync.firefox;

  # Firefox 150+ supports a dedicated Sync enterprise policy.
  #
  # Floorp remains account-disabled until its support for this
  # policy has been validated independently.
  firefoxSyncPolicies =
    if checkedBrowser == "firefox" && firefoxSyncCfg.enable then
      {
        Sync = {
          Enabled = true;
          Addons = firefoxSyncCfg.addons;
          Addresses = firefoxSyncCfg.addresses;
          Bookmarks = firefoxSyncCfg.bookmarks;
          History = firefoxSyncCfg.history;
          Locked = firefoxSyncCfg.locked;
          OpenTabs = firefoxSyncCfg.openTabs;
          Passwords = firefoxSyncCfg.passwords;
          PaymentMethods = firefoxSyncCfg.paymentMethods;
          Settings = firefoxSyncCfg.settings;
        };
      }
    else
      {
        DisableFirefoxAccounts = true;
      };

  cookieCfg = cfg.privacy.cookies;
  commonCookieCfg = cookieCfg.common;

  browserCookieCfg = cookieCfg.${checkedBrowser};
  profileCookieCfgs = cookieCfg.profiles.${checkedBrowser};

  profileCookieCfg =
    if profile != null && builtins.hasAttr profile profileCookieCfgs then
      profileCookieCfgs.${profile}
    else
      null;

  applyOriginLayer =
    inherited: layer:
    if layer.mode == "inherit" then
      inherited
    else if layer.mode == "extend" then
      lib.unique (inherited ++ layer.persistentOrigins)
    else if layer.mode == "replace" then
      lib.unique layer.persistentOrigins
    else if layer.mode == "none" then
      [ ]
    else
      throw "Unsupported Gecko cookie merge mode: ${layer.mode}";

  browserOrigins = applyOriginLayer (lib.unique commonCookieCfg.persistentOrigins) browserCookieCfg;

  effectiveOrigins =
    if profileCookieCfg == null then
      browserOrigins
    else
      applyOriginLayer browserOrigins profileCookieCfg;

  effectiveClearOnShutdown =
    if profileCookieCfg != null && profileCookieCfg.clearOnShutdown != null then
      profileCookieCfg.clearOnShutdown
    else if browserCookieCfg.clearOnShutdown != null then
      browserCookieCfg.clearOnShutdown
    else
      commonCookieCfg.clearOnShutdown;

  antiClutterPolicies = lib.optionalAttrs cfg.privacy.antiClutter.enable {
    FirefoxSuggest = {
      WebSuggestions = false;
      SponsoredSuggestions = false;
      ImproveSuggest = false;
      Locked = false;
    };

    FirefoxHome = {
      Search = true;
      TopSites = true;

      SponsoredTopSites = false;
      Highlights = false;

      Pocket = false;
      Stories = false;
      SponsoredPocket = false;
      SponsoredStories = false;

      Snippets = false;
      Weather = false;

      Locked = false;
    };

    UserMessaging = {
      ExtensionRecommendations = false;
      FeatureRecommendations = false;
      UrlbarInterventions = false;

      SkipOnboarding = true;
      MoreFromMozilla = false;
      FirefoxLabs = false;

      Locked = false;
    };
  };

  cookiePolicies = lib.optionalAttrs effectiveClearOnShutdown (
    {
      # Firefox/Floorp 152:
      # clear cookies and site storage while preserving useful
      # browser history and other runtime state.
      SanitizeOnShutdown = {
        Cache = false;
        Cookies = true;
        FormData = false;
        History = false;
        Sessions = false;
        SiteSettings = false;
        OfflineApps = false;

        Locked = false;
      };
    }
    // lib.optionalAttrs (effectiveOrigins != [ ]) {
      # Firefox <=153 uses Cookies.Allow as the persistence
      # exception mechanism for shutdown sanitization.
      #
      # Firefox 154+ introduces SanitizeOnShutdown.Exceptions.
      # Host configuration intentionally uses our own abstraction
      # so this implementation can later be migrated centrally.
      Cookies = {
        Allow = effectiveOrigins;
        Locked = false;
      };
    }
  );
in
{
  # ============================================================
  # Shared Firefox-compatible enterprise policies
  # ============================================================

  policies = lib.recursiveUpdate (
    {
      # Browser binaries themselves are updated through Nix.
      DisableAppUpdate = true;

      # Extensions may update independently.
      ExtensionUpdate = true;

      # XDG decides which browser is the system default.
      DontCheckDefaultBrowser = true;

      # Account/Sync policy is merged below so Firefox can opt into
      # selective Sync while unsupported Gecko derivatives stay disabled.

      # ==========================================================
      # Privacy / telemetry
      # ==========================================================

      DisableTelemetry = true;
      DisableFirefoxStudies = true;
      DisableFeedbackCommands = true;

      EnableTrackingProtection = {
        Value = true;
        Category = "strict";

        Cryptomining = true;
        Fingerprinting = true;
        EmailTracking = true;
        SuspectedFingerprinting = true;
        BaselineExceptions = true;
        ConvenienceExceptions = false;

        Locked = false;
      };

      # Remote search-engine suggestions are separate from local
      # history/bookmark/open-tab results.
      SearchSuggestEnabled = cfg.privacy.remoteSearchSuggestions.enable;

      # ==========================================================
      # Managed Gecko preferences
      # ==========================================================

      Preferences = {
        "browser.translations.automaticallyPopup" = {
          Value = false;
          Status = "locked";
        };

        "browser.translations.neverTranslateLanguages" = {
          Value = "de,en";
          Status = "locked";
        };

        "identity.fxaccounts.toolbar.enabled" = {
          Value = false;
          Status = "locked";
        };

        "identity.fxaccounts.toolbar.defaultVisible" = {
          Value = false;
          Status = "locked";
        };
      };

      # ==========================================================
      # DNS / HTTPS
      # ==========================================================

      DNSOverHTTPS = {
        Enabled = false;
        Locked = true;
      };

      HttpsOnlyMode = "enabled";

      # ==========================================================
      # Passwords / autofill
      # ==========================================================

      PasswordManagerEnabled = false;
      OfferToSaveLogins = false;

      AutofillAddressEnabled = false;
      AutofillCreditCardEnabled = false;

      # ==========================================================
      # Performance
      # ==========================================================

      HardwareAcceleration = true;

      # ==========================================================
      # Extensions
      # ==========================================================

      ExtensionSettings = effectiveExtensionSettings;
    }
    // firefoxSyncPolicies
    // antiClutterPolicies
    // cookiePolicies
  ) cfg.overrides.common.policies;

  # ============================================================
  # Shared profile preferences
  # ============================================================

  profileSettings = lib.recursiveUpdate (
    {
      "privacy.globalprivacycontrol.enabled" = true;

      # The dedicated "End Private Session" toolbar widget is
      # redundant for our normal browsing workflow.
      "browser.privatebrowsing.resetPBM.enabled" = false;

      # Keep useful local URL-bar sources enabled.
      "browser.urlbar.suggest.history" = true;
      "browser.urlbar.suggest.bookmark" = true;
      "browser.urlbar.suggest.openpage" = true;
      "browser.urlbar.suggest.engines" = true;
    }
    // lib.optionalAttrs cfg.extensions.tokyoNightTheme.enable {
      # Keep Firefox and Floorp on the same declarative
      # Tokyo Night theme when enabled for this host.
      "extensions.activeThemeID" = "{cebd391d-f568-473f-bb6e-698d08ec81ec}";
    }
    // lib.optionalAttrs cfg.privacy.antiClutter.enable {
      # Do not open the URL-bar view merely to show Top Sites.
      "browser.urlbar.suggest.topsites" = false;

      # Disable additional recommendation providers that are not
      # part of the useful local history/bookmark/tab sources.
      "browser.urlbar.suggest.addons" = false;
      "browser.urlbar.suggest.yelp" = false;
      "browser.urlbar.sponsoredTopSites" = false;

      # Defense in depth for Firefox Suggest / Quick Suggest.
      "browser.urlbar.quicksuggest.dataCollection.enabled" = false;
      "browser.urlbar.suggest.quicksuggest.sponsored" = false;
    }
  ) cfg.overrides.common.settings;
  # Useful for validation/debugging without duplicating merge logic.
  cookiePolicy = {
    inherit effectiveClearOnShutdown effectiveOrigins;
  };
}
