{ config, lib, ... }:

let
  cfg = config.hakkabara.browsers.gecko;

  shared = import ./shared.nix {
    inherit lib cfg;
    browser = "firefox";
    profile = cfg.firefox.profileName;
  };

  bookmarks = import ./bookmarks.nix;

  bookmarkPolicies = lib.optionalAttrs cfg.bookmarks.manager.enable bookmarks.policies;

  bookmarkProfileSettings = lib.optionalAttrs cfg.bookmarks.manager.enable bookmarks.profileSettings;

  firefoxNavbarWidgets =
    lib.optionals cfg.extensions.uBlockOrigin.enable [
      "ublock0_raymondhill_net-browser-action"
    ]
    ++ lib.optionals cfg.extensions.darkReader.enable [
      "addon_darkreader_org-browser-action"
    ]
    ++ lib.optionals cfg.extensions.bitwarden.enable [
      "_446900e4-71c2-419f-a6a7-df9c091e268b_-browser-action"
    ];

  firefoxExtensionAreaWidgets =
    lib.optionals cfg.extensions.consentOMatic.enable [
      "gdpr_cavi_au_dk-browser-action"
    ]
    ++ lib.optionals cfg.extensions.enhancerForYouTube.enable [
      "enhancerforyoutube_maximerf_addons_mozilla_org-browser-action"
    ]
    ++ lib.optionals cfg.extensions.multiAccountContainers.enable [
      "_testpilot-containers-browser-action"
    ]
    ++ lib.optionals cfg.extensions.sponsorBlock.enable [
      "sponsorblocker_ajay_app-browser-action"
    ];

  firefoxSettings = {
    "browser.uiCustomization.state" = builtins.toJSON {
      placements = {
        "widget-overflow-fixed-list" = [ ];

        "unified-extensions-area" = firefoxExtensionAreaWidgets;

        "nav-bar" = [
          "back-button"
          "forward-button"
          "stop-reload-button"
          "customizableui-special-spring1"
          "urlbar-container"
          "customizableui-special-spring2"
          "downloads-button"
          "unified-extensions-button"
        ]
        ++ firefoxNavbarWidgets;

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

      seen = lib.unique (firefoxNavbarWidgets ++ firefoxExtensionAreaWidgets);

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

  browserPolicies = lib.recursiveUpdate (lib.recursiveUpdate shared.policies bookmarkPolicies) cfg.overrides.firefox.policies;

  browserSettings = lib.recursiveUpdate (
    shared.profileSettings // bookmarkProfileSettings // firefoxSettings
  ) cfg.overrides.firefox.settings;
in
{
  programs.firefox = {
    enable = cfg.firefox.enable;

    languagePacks = [
      "de"
      "en-US"
    ];

    policies = browserPolicies;

    profiles.${cfg.firefox.profileName} = {
      id = cfg.firefox.profileId;
      name = cfg.firefox.profileDisplayName;
      isDefault = true;

      settings = browserSettings;

      search = import ./search.nix;
    };
  };
}
