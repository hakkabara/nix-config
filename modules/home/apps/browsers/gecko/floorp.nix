{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hakkabara.browsers.gecko;

  shared = import ./shared.nix {
    inherit lib cfg;
    browser = "floorp";
    profile = cfg.floorp.profileName;
  };

  bookmarks = import ./bookmarks.nix;
  bookmarkPolicies = lib.optionalAttrs cfg.bookmarks.manager.enable bookmarks.policies;

  bookmarkProfileSettings = lib.optionalAttrs cfg.bookmarks.manager.enable bookmarks.profileSettings;

  xwaylandGlxSettings = lib.optionalAttrs cfg.floorp.graphics.xwaylandGlx.enable {
    # VMware SVGA works correctly through GLX, while Floorp's EGL path
    # falls back to llvmpipe on the WorkVM.
    "gfx.x11-egl.force-disabled" = true;
  };

  floorpXwaylandGlxLauncher = pkgs.writeShellScriptBin "floorp-xwayland-glx" ''
    export GDK_BACKEND=x11
    export MOZ_ENABLE_WAYLAND=0
    export MOZ_WEBRENDER=1
    export MOZ_ACCELERATED=1

    exec ${config.programs.floorp.finalPackage}/bin/floorp "$@"
  '';

  # ============================================================
  # Floorp-specific stable profile preferences
  # ============================================================
  #
  # Only reproducible user-facing configuration belongs here.
  #
  # Deliberately unmanaged:
  # - experiment assignments / install IDs
  # - workspace UUID stores
  # - recent command history / frequencies
  # - sidebar panel data / extension IDs
  # - session/build timestamps
  # - current Split View pane sizes
  # - browser.uiCustomization.state
  # - other transient prefs.js state
  floorpSettings = {
    # ----------------------------------------------------------
    # Generic tab/window behavior
    # ----------------------------------------------------------
    "browser.tabs.closeWindowWithLastTab" = false;

    # Floorp-specific new-tab positioning.
    "floorp.browser.tabs.openNewTabPosition" = -1;

    # Do not show Floorp's first-run welcome page again.
    "floorp.browser.welcome.page.shown" = true;

    # ----------------------------------------------------------
    # Floorp UI / tabs
    # ----------------------------------------------------------
    #
    # Floorp 12 stores most native appearance settings in one
    # JSON preference. Keep only stable user-facing configuration
    # here rather than copying the entire runtime prefs.js state.
    "floorp.design.configs" = builtins.toJSON {
      globalConfigs = {
        appliedUserJs = "";
        faviconColor = false;
        userInterface = "lepton";
      };

      tabbar = {
        # Native Floorp multi-row tab layout.
        tabbarStyle = "multirow";
        tabbarPosition = "default";

        multiRowTabBar = {
          maxRowEnabled = true;
          maxRow = 2;
        };
      };

      tab = {
        tabDubleClickToClose = false;
        tabMinHeight = 30;
        tabMinWidth = 76;
        tabOpenPosition = -1;
        tabPinTitle = false;

        tabScroll = {
          enabled = false;
          reverse = false;
          wrap = false;
        };
      };

      uiCustomization = {
        # Keep the bookmarks toolbar enabled, but let Floorp
        # reveal it only when the toolbar area is focused/hovered.
        bookmarkBar = {
          focusExpand = true;
          position = "top";
        };

        display = {
          deleteBrowserBorder = false;
          disableFullscreenNotification = false;
        };

        multirowTab = {
          newtabInsideEnabled = false;
        };

        navbar = {
          position = "top";
          searchBarTop = false;
        };

        # Remove an unnecessary toolbar action.
        qrCode = {
          disableButton = true;
        };

        special = {
          hideForwardBackwardButton = false;
          optimizeForTreeStyleTab = false;
          stgLikeWorkspaces = false;
        };

        # Keep Floorp Start available. Its actual New Tab design
        # and background will be handled in a later dedicated block.
        disableFloorpStart = false;
      };
    };

    # ----------------------------------------------------------
    # Site Specific Browser / PWA-style windows
    # ----------------------------------------------------------
    "floorp.browser.ssb.enabled" = true;

    "floorp.browser.ssb.config" = builtins.toJSON {
      showToolbar = true;
    };

    # ----------------------------------------------------------
    # Command palette / keyboard shortcuts
    # ----------------------------------------------------------
    "floorp.commandPalette.enabled" = true;

    "floorp.keyboardshortcut.enabled" = true;

    # --------------------------------------------------------
    # Floorp Start / new tab
    # --------------------------------------------------------
    #
    # Floorp 12 stores the complete native Start configuration
    # as JSON in floorp.newtab.configs.
    #
    # Keep useful dynamic Top Sites, while removing Floorp's
    # default pinned sponsor/support entries and redundant UI.
    "floorp.newtab.configs" = builtins.toJSON {
      components = {
        topSites = true;
        clock = false;
        searchBar = false;
        firefoxLayout = false;
      };

      background = {
        # Use the Home Manager managed wallpaper directory.
        # With one image this behaves as a fixed wallpaper; adding
        # more images later makes random/slideshow use possible
        # without changing the runtime path.
        type = "folderPath";
        customImage = null;
        fileName = null;
        folderPath = "${config.xdg.dataHome}/floorp/newtab";
        selectedFloorp = null;
        slideshowEnabled = false;
        slideshowInterval = 30;
      };

      searchBar = {
        searchEngine = "default";
      };

      topSites = {
        pinned = [ ];
        blocked = [ ];
      };
    };

    "floorp.keyboardshortcut.config" = builtins.toJSON {
      schemaVersion = 2;
      enabled = true;

      shortcuts = {
        # --------------------------------------------------------
        # Command palette
        # --------------------------------------------------------
        #
        # The palette remains the central launcher for less common
        # actions and also serves as the workspace picker.
        "floorp-toggle-command-palette" = {
          action = "floorp-toggle-command-palette";
          key = "F2";

          modifiers = {
            alt = false;
            ctrl = false;
            meta = false;
            shift = false;
          };
        };

        # --------------------------------------------------------
        # Workspaces
        # --------------------------------------------------------
        "workspace-previous" = {
          action = "gecko-workspace-previous";
          key = "ArrowLeft";

          modifiers = {
            alt = true;
            ctrl = false;
            meta = false;
            shift = true;
          };
        };

        "workspace-next" = {
          action = "gecko-workspace-next";
          key = "ArrowRight";

          modifiers = {
            alt = true;
            ctrl = false;
            meta = false;
            shift = true;
          };
        };

        # --------------------------------------------------------
        # Split View
        # --------------------------------------------------------
        #
        # Opening to the right creates Floorp's tab-picker pane.
        "split-view-open" = {
          action = "floorp-split-view-open-right";
          key = "S";

          modifiers = {
            alt = true;
            ctrl = false;
            meta = false;
            shift = true;
          };
        };

        "split-view-close" = {
          action = "floorp-split-view-close";
          key = "X";

          modifiers = {
            alt = true;
            ctrl = false;
            meta = false;
            shift = true;
          };
        };

        "split-view-cycle-layout" = {
          action = "floorp-split-view-cycle-layout";
          key = "L";

          modifiers = {
            alt = true;
            ctrl = false;
            meta = false;
            shift = true;
          };
        };

        # --------------------------------------------------------
        # Tab navigation / TailorKey
        # --------------------------------------------------------
        #
        # TailorKey's Ctrl-Tab switcher keeps Ctrl held while its
        # Cursor layer emits Left/Right. Map those directions to
        # previous/next browser tab.
        "gecko-show-previous-tab" = {
          action = "gecko-show-previous-tab";
          key = "ArrowLeft";

          modifiers = {
            alt = false;
            ctrl = true;
            meta = false;
            shift = false;
          };
        };

        "gecko-show-next-tab" = {
          action = "gecko-show-next-tab";
          key = "ArrowRight";

          modifiers = {
            alt = false;
            ctrl = true;
            meta = false;
            shift = false;
          };
        };

        # Keep Niri Super+Q for closing the complete window while
        # Super+Shift+Q closes only the current Floorp tab.
        "gecko-close-tab" = {
          action = "gecko-close-tab";
          key = "KeyQ";

          modifiers = {
            alt = false;
            ctrl = false;
            meta = true;
            shift = true;
          };
        };

        # --------------------------------------------------------
        # Zen Mode
        # --------------------------------------------------------
        "floorp-toggle-zen-mode" = {
          action = "floorp-toggle-zen-mode";
          key = "KeyZ";

          modifiers = {
            alt = true;
            ctrl = true;
            meta = false;
            shift = false;
          };
        };
      };
    };

    # ----------------------------------------------------------
    # Mouse gestures
    # ----------------------------------------------------------
    "floorp.mousegesture.enabled" = false;

    # ----------------------------------------------------------
    # Floorp Panel Sidebar
    # ----------------------------------------------------------
    #
    # Keep the feature available for keyboard / command-palette
    # use, but do not display it permanently.
    #
    # Panel contents themselves remain Floorp-managed runtime
    # state in floorp.panelSidebar.data.
    "floorp.panelSidebar.enabled" = false;

    "floorp.panelSidebar.config" = builtins.toJSON {
      autoUnload = false;
      displayed = false;
      globalWidth = 400;
      position_start = true;
      webExtensionRunningEnabled = false;
    };

    # ----------------------------------------------------------
    # Workspaces
    # ----------------------------------------------------------
    #
    # Feature behavior is declarative. The actual UUID-based
    # workspace store stays under Floorp's control.
    "floorp.workspaces.enabled" = true;

    "floorp.workspaces.v4.config" = builtins.toJSON {
      closePopupAfterClick = true;
      exitOnLastTabClose = false;
      manageOnBms = false;

      # Less permanent toolbar clutter. Workspace switching will
      # primarily happen via keyboard / command palette.
      showWorkspaceNameOnToolbar = false;
    };

    # ----------------------------------------------------------
    # Split View
    # ----------------------------------------------------------
    #
    # Layout is configuration; pane-size state remains runtime.
    "floorp.splitView.config" = builtins.toJSON {
      layout = "horizontal";
      maxPanes = 4;
    };

    # ----------------------------------------------------------
    # Zen mode
    # ----------------------------------------------------------
    "floorp.zenmode.enabled" = false;
  };
in
{
  # Deploy the Floorp Start wallpaper to a stable XDG data path.
  #
  # Keep the runtime path stable so replacing the repository asset
  # later requires no browser configuration changes.
  xdg.dataFile."floorp/newtab/tokyo-night.png" = lib.mkIf cfg.floorp.enable {
    source = ../../../../../assets/floorp/newtab/tokyo-night.png;
  };

  # Expose the accelerated Floorp launcher as a command as well.
  # This lets Niri shortcuts use the same tested VMware GLX path.
  home.packages = lib.optionals (cfg.floorp.enable && cfg.floorp.graphics.xwaylandGlx.enable) [
    floorpXwaylandGlxLauncher
  ];

  # Override only Floorp's desktop launcher when the GLX workaround
  # is enabled. Niri and all other applications remain native Wayland.
  xdg.desktopEntries.floorp = lib.mkIf (cfg.floorp.enable && cfg.floorp.graphics.xwaylandGlx.enable) {
    name = "Floorp";
    genericName = "Web Browser";
    comment = "Browse the Web";
    icon = "floorp";

    exec = "${floorpXwaylandGlxLauncher}/bin/floorp-xwayland-glx --name floorp %U";

    terminal = false;
    startupNotify = true;

    categories = [
      "Network"
      "WebBrowser"
    ];

    mimeType = [
      "text/html"
      "text/xml"
      "application/xhtml+xml"
      "application/vnd.mozilla.xul+xml"
      "x-scheme-handler/http"
      "x-scheme-handler/https"
    ];

    settings.StartupWMClass = "floorp";

    actions = {
      new-window = {
        name = "New Window";
        exec = "${floorpXwaylandGlxLauncher}/bin/floorp-xwayland-glx --new-window %U";
      };

      new-private-window = {
        name = "New Private Window";
        exec = "${floorpXwaylandGlxLauncher}/bin/floorp-xwayland-glx --private-window %U";
      };

      profile-manager-window = {
        name = "Profile Manager";
        exec = "${floorpXwaylandGlxLauncher}/bin/floorp-xwayland-glx --ProfileManager";
      };
    };
  };

  programs.floorp = {
    enable = cfg.floorp.enable;

    # Firefox-compatible baseline shared with Firefox.
    policies = lib.recursiveUpdate (lib.recursiveUpdate shared.policies bookmarkPolicies) cfg.overrides.floorp.policies;

    # Floorp keeps its own profile state below ~/.floorp.
    profiles.${cfg.floorp.profileName} = {
      id = cfg.floorp.profileId;
      name = cfg.floorp.profileDisplayName;
      isDefault = true;

      # Minimal declarative Floorp chrome cleanup.
      #
      # Do not serialize browser.uiCustomization.state: it contains
      # version- and runtime-specific placement state. Hide only the
      # stable widget IDs that are redundant for this profile.
      userChrome = ''
        #profile-manager-button,
        #undo-closed-tab,
        #import-button,
        #firefox-view-button {
          display: none !important;
        }
      '';

      settings = lib.recursiveUpdate (
        shared.profileSettings // bookmarkProfileSettings // floorpSettings // xwaylandGlxSettings
      ) cfg.overrides.floorp.settings;

      search = import ./search.nix;
    };

    # Dedicated single-purpose Floorp profile for WhatsApp.
    #
    # Keep WhatsApp separate from the normal Surf profile so
    # session restore and ordinary browser tabs cannot become
    # part of the WhatsApp autostart window.
    profiles.whatsapp = lib.mkIf cfg.floorp.whatsappProfile.enable {
      id = 1;
      name = "WhatsApp";
      isDefault = false;

      settings =
        shared.profileSettings
        // floorpSettings
        // {
          # The autostart launcher supplies web.whatsapp.com
          # explicitly, so this profile itself starts empty.
          "browser.startup.page" = 0;
          "browser.startup.homepage" = "about:blank";

          # Do not resurrect old WhatsApp browser windows after a
          # crash. The dedicated autostart launcher is authoritative.
          "browser.sessionstore.resume_from_crash" = false;
          "browser.sessionstore.max_resumed_crashes" = 0;

          # Workspaces are useful in the normal browser, not in the
          # dedicated single-purpose WhatsApp instance.
          "floorp.workspaces.enabled" = false;
        };
    };
  };
}
