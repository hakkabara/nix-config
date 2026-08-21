{ config, lib, ... }:

let
  cfg = config.hakkabara.browsers.gecko;

  shared = import ./shared.nix {
    inherit lib cfg;
  };

  bookmarks = import ./bookmarks.nix;

  browserBaseline = lib.recursiveUpdate shared.policies bookmarks.policies;
in
{
  programs.firefox = {
    enable = cfg.firefox.enable;

    languagePacks = [
      "de"
      "en-US"
    ];

    # ==============================    # ============================================================
    # Firefox enterprise policies
    # ============================================================

    policies = lib.recursiveUpdate browserBaseline {
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

      settings =
        shared.profileSettings
        // bookmarks.profileSettings
        // {
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

      # Shared with other Gecko browsers such as Floorp.
      search = import ./search.nix;

      # ==========================================================
      # Containers
      # ==========================================================
      #
      #
    };
  };
}
