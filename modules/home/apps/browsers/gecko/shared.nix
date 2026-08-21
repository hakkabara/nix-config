{ lib, cfg }:

let
  extensionSettings = import ./extensions.nix {
    inherit lib;
    cfg = cfg.extensions;
  };
in
{
  # ============================================================
  # Shared Firefox-compatible enterprise policies
  # ============================================================

  policies = {
    # Browser binaries themselves are updated through Nix.
    DisableAppUpdate = true;

    # Extensions may update independently.
    ExtensionUpdate = true;

    # XDG decides which browser is the system default.
    DontCheckDefaultBrowser = true;

    # Browser sync/accounts are intentionally not part of our
    # reproducible configuration.
    DisableFirefoxAccounts = true;

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

    # ==========================================================
    # Managed Gecko preferences
    # ==========================================================

    Preferences = {
      # Do not automatically show the translation popup.
      # Manual translation remains available.
      "browser.translations.automaticallyPopup" = {
        Value = false;
        Status = "locked";
      };

      # German and English do not need translation offers.
      "browser.translations.neverTranslateLanguages" = {
        Value = "de,en";
        Status = "locked";
      };

      # Hide Firefox Account / Sync UI in Firefox-compatible
      # browsers.
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

    # Respect the operating system, VPN and split-DNS setup.
    DNSOverHTTPS = {
      Enabled = false;
      Locked = true;
    };

    # Prefer HTTPS while still permitting explicit HTTP access.
    HttpsOnlyMode = "enabled";

    # ==========================================================
    # Passwords / autofill
    # ==========================================================

    # Bitwarden is used instead of the browser password manager.
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

    ExtensionSettings = extensionSettings;
  };

  # ============================================================
  # Shared profile preferences
  # ============================================================

  profileSettings = {
    "privacy.globalprivacycontrol.enabled" = true;
  };
}
