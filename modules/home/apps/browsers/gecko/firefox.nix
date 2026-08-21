{ config, lib, ... }:

let
  cfg = config.hakkabara.browsers.gecko;
  extensionSettings = import ./extensions.nix {
    inherit lib;
    cfg = cfg.extensions;
  };
in
{
  programs.firefox = {
    enable = cfg.firefox.enable;

    languagePacks = [
      "de"
      "en-US"
    ];

    # ============================================================
    # Firefox enterprise policies
    # ============================================================

    policies = {
      # Firefox itself is updated through Nix.
      DisableAppUpdate = true;

      # Extensions may update independently.
      ExtensionUpdate = true;

      # Vivaldi remains the system default browser.
      DontCheckDefaultBrowser = true;

      # Firefox Accounts / Sync are intentionally unused.
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
      # Managed Firefox preferences
      # ==========================================================

      Preferences = {
        # Never automatically open Firefox's translation popup.
        # Manual translation remains available.
        "browser.translations.automaticallyPopup" = {
          Value = false;
          Status = "locked";
        };

        # Never offer translation for German or English.
        "browser.translations.neverTranslateLanguages" = {
          Value = "de,en";
          Status = "locked";
        };

        # Hide Firefox Account / Sync UI.
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

      # Use the OS / VPN DNS configuration.
      #
      # This is important for split DNS and VPN configurations.
      DNSOverHTTPS = {
        Enabled = false;
        Locked = true;
      };

      # Prefer HTTPS while still permitting manual HTTP exceptions.
      HttpsOnlyMode = "enabled";

      # ==========================================================
      # Passwords / autofill
      # ==========================================================

      # Bitwarden is the password manager.
      PasswordManagerEnabled = false;
      OfferToSaveLogins = false;

      AutofillAddressEnabled = false;
      AutofillCreditCardEnabled = false;

      # ==========================================================
      # Bookmarks
      # ==========================================================

      # Declarative encrypted bookmarks are our source of truth.
      NoDefaultBookmarks = true;

      DisplayBookmarksToolbar = "always";

      # ==========================================================
      # Firefox Home / sponsored content
      # ==========================================================

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

        Locked = false;
      };

      FirefoxSuggest = {
        WebSuggestions = true;

        SponsoredSuggestions = false;
        ImproveSuggest = false;

        Locked = false;
      };

      # ==========================================================
      # Performance
      # ==========================================================

      HardwareAcceleration = true;

      # ==========================================================
      # Extensions
      # ==========================================================

      ExtensionSettings = extensionSettings;

      # ==========================================================
      # Firefox theme
      # ==========================================================
      #
      # Catppuccin 1.0 by Labrat.
      #
      # Pinned to the concrete AMO XPI instead of /latest/.

      Extensions = {
        Install = [
          "https://addons.mozilla.org/firefox/downloads/file/3880040/catppuccin-1.0.xpi"
        ];
      };
    };

    # ============================================================
    # Personal SurfVM Firefox profile
    # ============================================================

    profiles.surf = {
      id = 0;
      name = "Surf";
      isDefault = true;

      # ==========================================================
      # Firefox profile settings
      # ==========================================================

      settings = {
        # --------------------------------------------------------
        # Declarative encrypted bookmarks
        # --------------------------------------------------------
        #
        # Encrypted source:
        #
        # /home/hakkabara/nix-config/secrets/surf-vm/firefox-bookmarks
        #
        # Runtime plaintext:
        #
        # /run/secrets/firefox/bookmarks

        "browser.bookmarks.file" = "/run/secrets/firefox/bookmarks";

        "browser.places.importBookmarksHTML" = true;

        "browser.toolbars.bookmarks.visibility" = "always";

        "browser.toolbars.bookmarks.showOtherBookmarks" = false;

        # --------------------------------------------------------
        # Privacy
        # --------------------------------------------------------

        "privacy.globalprivacycontrol.enabled" = true;

        # --------------------------------------------------------
        # UI recommendations / sponsored content
        # --------------------------------------------------------

        "browser.newtabpage.activity-stream.asrouter.userprefs.cfr.addons" = false;

        "browser.newtabpage.activity-stream.asrouter.userprefs.cfr.features" = false;

        "browser.urlbar.suggest.quicksuggest.sponsored" = false;

        "browser.urlbar.quicksuggest.dataCollection.enabled" = false;

        # --------------------------------------------------------
        # Declarative Firefox toolbar
        # --------------------------------------------------------
        #
        # Navbar:
        #   - Back / Forward / Reload
        #   - URL bar
        #   - Downloads
        #   - Extensions menu
        #   - uBlock Origin
        #   - Dark Reader
        #   - Bitwarden
        #
        # Firefox Account / Sync is deliberately omitted.
        #
        # Other extensions remain installed and accessible through
        # the unified extensions menu.

        "browser.uiCustomization.state" = builtins.toJSON {
          placements = {
            "widget-overflow-fixed-list" = [ ];

            "unified-extensions-area" = [
              "gdpr_cavi_au_dk-browser-action"
              "enhancerforyoutube_maximerf_addons_mozilla_org-browser-action"
              "_testpilot-containers-browser-action"
              "sponsorblocker_ajay_app-browser-action"
            ];

            "nav-bar" = [
              "back-button"
              "forward-button"
              "stop-reload-button"

              "customizableui-special-spring1"
              "urlbar-container"
              "customizableui-special-spring2"

              "downloads-button"
              "unified-extensions-button"

              "ublock0_raymondhill_net-browser-action"
              "addon_darkreader_org-browser-action"
              "_446900e4-71c2-419f-a6a7-df9c091e268b_-browser-action"
            ];

            "toolbar-menubar" = [
              "menubar-items"
            ];

            TabsToolbar = [
              "firefox-view-button"
              "tabbrowser-tabs"
              "new-tab-button"
              "alltabs-button"
            ];

            "vertical-tabs" = [ ];

            PersonalToolbar = [
              "personal-bookmarks"
            ];
          };

          seen = [
            "gdpr_cavi_au_dk-browser-action"
            "enhancerforyoutube_maximerf_addons_mozilla_org-browser-action"
            "_testpilot-containers-browser-action"
            "sponsorblocker_ajay_app-browser-action"

            "ublock0_raymondhill_net-browser-action"
            "addon_darkreader_org-browser-action"
            "_446900e4-71c2-419f-a6a7-df9c091e268b_-browser-action"
          ];

          dirtyAreaCache = [
            "nav-bar"
            "vertical-tabs"
            "PersonalToolbar"
            "toolbar-menubar"
            "TabsToolbar"
            "unified-extensions-area"
          ];

          currentVersion = 24;
          newElementCount = 0;
        };
      };

      # ==========================================================
      # Search engines
      # ==========================================================
      #
      # Usage examples:
      #
      # @ddg nixos
      # @g nixos
      # @yt nixos tutorial
      #
      # @nix firefox
      # @np ripgrep
      #
      # @no services.openssh
      # @nixopt networking.firewall
      #
      # @nw wireguard
      #
      # @aw systemd
      # @arch networkmanager
      #
      # @gh sops-nix
      # @github home-manager
      #
      # @sh nginx
      # @shodan port:443 country:DE
      #
      # @wiki NixOS

      search = {
        force = true;

        # DuckDuckGo everywhere unless an explicit alias is used.
        default = "ddg";
        privateDefault = "ddg";

        order = [
          "ddg"
          "google"
          "youtube"

          "nix-packages"
          "nixos-options"
          "nixos-wiki"
          "arch-wiki"

          "github"
          "shodan"

          "wikipedia-de"
        ];

        engines = {
          # ------------------------------------------------------
          # Built-in Firefox engines
          # ------------------------------------------------------

          ddg.metaData.alias = "@ddg";

          google.metaData.alias = "@g";

          youtube.metaData.alias = "@yt";

          "wikipedia-de".metaData.alias = "@wiki";

          # ------------------------------------------------------
          # Nix Packages
          #
          # @nix firefox
          # @np ripgrep
          # ------------------------------------------------------

          "nix-packages" = {
            name = "Nix Packages";

            urls = [
              {
                template = "https://search.nixos.org/packages";

                params = [
                  {
                    name = "type";
                    value = "packages";
                  }
                  {
                    name = "query";
                    value = "{searchTerms}";
                  }
                ];
              }
            ];

            definedAliases = [
              "@nix"
              "@np"
            ];
          };

          # ------------------------------------------------------
          # NixOS Options
          #
          # @no services.openssh
          # @nixopt networking.firewall
          # ------------------------------------------------------

          "nixos-options" = {
            name = "NixOS Options";

            urls = [
              {
                template = "https://search.nixos.org/options";

                params = [
                  {
                    name = "channel";
                    value = "26.05";
                  }
                  {
                    name = "query";
                    value = "{searchTerms}";
                  }
                ];
              }
            ];

            definedAliases = [
              "@no"
              "@nixopt"
            ];
          };

          # ------------------------------------------------------
          # NixOS Wiki
          #
          # @nw wireguard
          # ------------------------------------------------------

          "nixos-wiki" = {
            name = "NixOS Wiki";

            urls = [
              {
                template = "https://wiki.nixos.org/w/index.php?search={searchTerms}";
              }
            ];

            definedAliases = [
              "@nw"
            ];
          };

          # ------------------------------------------------------
          # ArchWiki
          #
          # @aw systemd
          # @arch networkmanager
          # ------------------------------------------------------

          "arch-wiki" = {
            name = "ArchWiki";

            urls = [
              {
                template = "https://wiki.archlinux.org/title/Special:Search";

                params = [
                  {
                    name = "search";
                    value = "{searchTerms}";
                  }
                ];
              }
            ];

            definedAliases = [
              "@aw"
              "@arch"
            ];
          };

          # ------------------------------------------------------
          # GitHub
          #
          # @gh sops-nix
          # @github home-manager
          # ------------------------------------------------------

          github = {
            name = "GitHub";

            urls = [
              {
                template = "https://github.com/search";

                params = [
                  {
                    name = "q";
                    value = "{searchTerms}";
                  }
                ];
              }
            ];

            definedAliases = [
              "@gh"
              "@github"
            ];
          };

          # ------------------------------------------------------
          # Shodan
          #
          # @sh nginx
          # @shodan port:443 country:DE
          # ------------------------------------------------------

          shodan = {
            name = "Shodan";

            urls = [
              {
                template = "https://www.shodan.io/search";

                params = [
                  {
                    name = "query";
                    value = "{searchTerms}";
                  }
                ];
              }
            ];

            definedAliases = [
              "@sh"
              "@shodan"
            ];
          };
        };
      };

      # ==========================================================
      # Containers
      # ==========================================================
      #
      #
    };
  };
}
