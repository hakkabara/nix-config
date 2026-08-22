{ config, lib, ... }:

let
  cfg = config.hakkabara.browsers.gecko;

  shared = import ./shared.nix {
    inherit lib cfg;
  };

  bookmarks = import ./bookmarks.nix;

  # ============================================================
  # Floorp-specific stable profile preferences
  # ============================================================
  #
  # Only reproducible user-facing configuration belongs here.
  #
  # Do not copy transient prefs.js state such as:
  # - experiment assignments / install IDs
  # - workspace UUID stores
  # - command history / frequency
  # - sidebar extension IDs
  # - session/build timestamps
  # - current pane sizes
  # - browser.uiCustomization.state
  floorpSettings = {
    # Keep the browser window open when the last tab is closed.
    "browser.tabs.closeWindowWithLastTab" = false;

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

    "floorp.keyboardshortcut.config" = builtins.toJSON {
      enabled = true;

      shortcuts = {
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
      };
    };

    # ----------------------------------------------------------
    # Mouse gestures
    # ----------------------------------------------------------
    # Disabled intentionally. Do not persist Floorp's gesture
    # history / last-enabled state.
    "floorp.mousegesture.enabled" = false;

    # ----------------------------------------------------------
    # Floorp Panel Sidebar
    # ----------------------------------------------------------
    "floorp.panelSidebar.enabled" = true;

    "floorp.panelSidebar.config" = builtins.toJSON {
      autoUnload = false;
      displayed = true;
      globalWidth = 400;
      position_start = true;
      webExtensionRunningEnabled = false;
    };

    # ----------------------------------------------------------
    # Workspaces
    # ----------------------------------------------------------
    # Enable the feature, but deliberately leave the UUID-based
    # workspace store under Floorp's control.
    "floorp.workspaces.enabled" = true;

    "floorp.workspaces.v4.config" = builtins.toJSON {
      closePopupAfterClick = false;
      exitOnLastTabClose = false;
      manageOnBms = false;
      showWorkspaceNameOnToolbar = true;
    };

    # ----------------------------------------------------------
    # Zen mode
    # ----------------------------------------------------------
    "floorp.zenmode.enabled" = false;
  };
in
{
  programs.floorp = {
    enable = cfg.floorp.enable;

    # Firefox-compatible baseline shared with Firefox.
    policies = lib.recursiveUpdate shared.policies bookmarks.policies;

    # Floorp keeps its own profile state below ~/.floorp.
    profiles.surf = {
      id = 0;
      name = "Surf";
      isDefault = true;

      settings = shared.profileSettings // bookmarks.profileSettings // floorpSettings;

      search = import ./search.nix;
    };
  };
}
