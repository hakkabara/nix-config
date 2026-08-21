{ ... }:

let
  cssFilterTheme = {
    mode = 1;
    brightness = 100;
    contrast = 100;
    grayscale = 0;
    sepia = 0;

    useFont = false;
    fontFamily = "Open Sans";
    textStroke = 0;

    engine = "cssFilter";
    stylesheet = "";

    darkSchemeBackgroundColor = "#181a1b";
    darkSchemeTextColor = "#e8e6e3";

    lightSchemeBackgroundColor = "#dcdad7";
    lightSchemeTextColor = "#181a1b";

    scrollbarColor = "";
    selectionColor = "auto";

    styleSystemControls = false;

    lightColorScheme = "Default";
    darkColorScheme = "Default";

    immediateModify = false;
  };
in
{
  hakkabara.browsers.gecko.extensions = {
    # ==========================================================
    # uBlock Origin
    #
    # enable is controlled by the workstation/profile layer.
    #
    # settings.enable only controls whether OUR declarative
    # configuration is applied.
    # ==========================================================

    uBlockOrigin = {
      settings.enable = true;

      userSettings = {
        advancedUserEnabled = true;

        # Allow trusted/scriptlet-based rules from "My filters".
        userFiltersTrusted = true;

        uiTheme = "dark";
        popupPanelSections = 31;
      };

      advancedSettings = {
        # Stable uBO trusts only its own ublock-* lists by default.
        #
        # user- additionally trusts rules from our declaratively managed
        # "My filters" pane, which is required for TwitchAdSolutions'
        # custom +js() resource.
        trustedListPrefixes = "ublock- user-";
      };

      stockFilterLists = [
        "user-filters"
        "ublock-filters"
        "ublock-badware"
        "ublock-privacy"
        "ublock-quick-fixes"
        "ublock-unbreak"
        "easylist"
        "easyprivacy"
        "urlhaus-1"
        "plowe-0"
        "fanboy-cookiemonster"
        "ublock-cookies-easylist"
        "adguard-cookies"
        "ublock-cookies-adguard"
        "DEU-0"
      ];

      externalFilterLists = [
        "https://cdn.jsdelivr.net/gh/BevizLaszlo/UBlock-Filters-for-Social-Media@latest/dist/instagram.txt"
        "https://gitflic.ru/project/magnolia1234/bypass-paywalls-clean-filters/blob/raw?file=bpc-paywall-filter.txt&commit=845d90c515b0ac6f918363c474d8c73826c8072c"
        "https://raw.githubusercontent.com/DandelionSprout/adfilt/master/AnnoyancesList"
        "https://raw.githubusercontent.com/DandelionSprout/adfilt/master/LegitimateURLShortener.txt"
        "https://raw.githubusercontent.com/DandelionSprout/adfilt/refs/heads/master/ClearURLs%20for%20uBo/clear_urls_uboified.txt"
        "https://raw.githubusercontent.com/Suurp/uBlock-CustomFilters/refs/heads/main/filters-faucets.txt"
        "https://raw.githubusercontent.com/Suurp/uBlock-CustomFilters/refs/heads/main/filters-shortlinks.txt"
        "https://raw.githubusercontent.com/gijsdev/ublock-hide-yt-shorts/refs/heads/master/list.txt"
        "https://raw.githubusercontent.com/laylavish/uBlockOrigin-HUGE-AI-Blocklist/main/list.txt"
        "https://raw.githubusercontent.com/liamengland1/miscfilters/refs/heads/master/antipaywall.txt"
      ];

      resourceLocations = [ ];

      hiddenSettings = { };

      trustedSites = [
        "chrome-extension-scheme"
        "moz-extension-scheme"
      ];

      dynamicFiltering = [
        "behind-the-scene * * noop"
        "behind-the-scene * inline-script noop"
        "behind-the-scene * 1p-script noop"
        "behind-the-scene * 3p-script noop"
        "behind-the-scene * 3p-frame noop"
        "behind-the-scene * image noop"
        "behind-the-scene * 3p noop"
      ];

      urlFiltering = [ ];

      hostnameSwitches = [
        "no-large-media: behind-the-scene false"
        "no-csp-reports: * true"
      ];

      # Add your own My Filters entries here.
      #
      # TwitchAdSolutions appends its filter automatically.
      userFilters = [ ];
    };

    # ==========================================================
    # Dark Reader
    #
    # enable:
    #   install extension
    #
    # settings.enable:
    #   generate/apply our settings
    #
    # settings.data:
    #   actual Dark Reader configuration
    # ==========================================================

    darkReader.settings = {
      enable = true;

      data = {
        schemeVersion = 2;
        enabled = true;
        fetchNews = true;

        theme = {
          mode = 1;
          brightness = 100;
          contrast = 100;
          grayscale = 0;
          sepia = 0;

          useFont = false;
          fontFamily = "Open Sans";
          textStroke = 0;

          engine = "dynamicTheme";
          stylesheet = "";

          darkSchemeBackgroundColor = "#1e1e2e";
          darkSchemeTextColor = "#cdd6f4";

          lightSchemeBackgroundColor = "#dcdad7";
          lightSchemeTextColor = "#181a1b";

          scrollbarColor = "";
          selectionColor = "#005ccc";

          styleSystemControls = false;

          lightColorScheme = "Default";
          darkColorScheme = "Catppuccin";

          immediateModify = false;
        };

        presets = [ ];

        customThemes = [
          {
            url = [ "*.officeapps.live.com" ];
            theme = cssFilterTheme;
            builtIn = true;
          }

          {
            url = [ "*.sharepoint.com" ];
            theme = cssFilterTheme;
            builtIn = true;
          }

          {
            url = [ "docs.google.com" ];
            theme = cssFilterTheme;
            builtIn = true;
          }

          {
            url = [ "onedrive.live.com" ];
            theme = cssFilterTheme;
            builtIn = true;
          }
        ];

        enabledByDefault = true;

        enabledFor = [ ];

        # ======================================================
        # DARK READER EXCEPTIONS
        #
        # Add sites here where Dark Reader should stay disabled.
        #
        # Example:
        #
        # disabledFor = [
        #   "github.com"
        #   "example.com"
        # ];
        # ======================================================
        disabledFor = [ ];

        changeBrowserTheme = true;

        syncSettings = false;
        syncSitesFixes = false;

        automation = {
          enabled = false;
          mode = "";
          behavior = "OnOff";
        };

        time = {
          activation = "18:00";
          deactivation = "9:00";
        };

        location = {
          latitude = null;
          longitude = null;
        };

        previewNewDesign = true;
        previewNewestDesign = false;

        enableForPDF = true;

        enableForProtectedPages = true;

        enableContextMenus = false;
        detectDarkTheme = true;
      };
    };

    # ==========================================================
    # TwitchAdSolutions
    # ==========================================================

    twitchAdSolutions = {
      solution = "vaft";

      # Change to:
      #
      #   delivery = "userscript";
      #
      # if the uBlock delivery stops working reliably.
      delivery = "ublock";

      repository = "ryanbr/TwitchAdSolutions";

      revision = "232c5e95f915ccf59eac175044bb19ad24f84227";

      # Independent from the actual VAFT delivery.
      #
      # This only maintains the localStorage runtime preferences.
      runtimeConfig.enable = true;

      runtime = {
        reloadPlayerAfterAd = false;

        playerType = "popout";

        hideAdOverlay = true;

        # null means:
        #
        # remove our override and use the current upstream default.
        pinBackupPlayerType = null;
        reloadCooldownSeconds = null;
        disableReloadCap = null;
        preferLowQualityBackup = null;
        backupSwapFirst = null;
      };
    };
  };
}
