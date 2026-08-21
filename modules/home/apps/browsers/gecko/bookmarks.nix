{
  # ============================================================
  # Shared Gecko bookmark configuration
  # ============================================================
  #
  # Firefox and Floorp do NOT share their browser databases.
  #
  # Each browser imports the same host-specific bookmark source
  # exposed by sops-nix at:
  #
  #   /run/secrets/browser/bookmarks
  #
  # The host decides which encrypted bookmark set is exposed.
  #
  # SurfVM:
  #   private bookmarks for hakkabara
  #
  # Future WorkVM:
  #   separate work bookmarks for mko

  policies = {
    DisplayBookmarksToolbar = "always";
  };

  profileSettings = {
    "browser.bookmarks.file" = "/run/secrets/browser/bookmarks";
    "browser.places.importBookmarksHTML" = true;

    "browser.toolbars.bookmarks.visibility" = "always";
    "browser.toolbars.bookmarks.showOtherBookmarks" = false;
  };
}
