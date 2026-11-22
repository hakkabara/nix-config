{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hakkabara.apps.thunar;
in
{
  options.hakkabara.apps.thunar = {
    enable = lib.mkEnableOption "Thunar as graphical file manager, hardened for evidence handling";

    user = lib.mkOption {
      type = lib.types.str;
      description = "User whose Thunar preferences (xfconf) are managed.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.hasAttr cfg.user config.users.users;
        message = "hakkabara.apps.thunar.user must reference an existing user";
      }
    ];

    programs.thunar = {
      enable = true;

      # No thunar-volman: removable media (possibly evidence) must never be
      # mounted automatically.
      plugins = [ pkgs.thunar-archive-plugin ];
    };

    # Trash, sftp:// and other remote locations. gvfs keeps its metadata in
    # ~/.local/share/gvfs-metadata, not in the browsed directories.
    services.gvfs.enable = true;

    # Thumbnailers parse every file in a folder, including malware samples
    # and evidence. Keep the D-Bus thumbnail service off.
    services.tumbler.enable = lib.mkForce false;

    # System-wide default for folders; entries in ~/.config/mimeapps.list
    # still take precedence.
    xdg.mime.defaultApplications."inode/directory" = "thunar.desktop";

    home-manager.users.${cfg.user}.xfconf.settings.thunar = {
      # Names and values verified against the Thunar 4.20 sources
      # (thunar/thunar-preferences.c, thunar-enum-types.c).
      "misc-thumbnail-mode" = "THUNAR_THUMBNAIL_MODE_NEVER";

      # Shell scripts open in an editor instead of running. ELF binaries with
      # the executable bit still run on double-click (Thunar has no switch for
      # them); only a noexec mount prevents that.
      "misc-exec-shell-scripts-by-default" = "THUNAR_EXECUTE_SHELL_SCRIPT_NEVER";

      "misc-volume-management" = false;

      # Per-folder view settings are not written anywhere near the evidence.
      "misc-directory-specific-settings" = false;

      # Show where you are: editable path bar, full path in the title,
      # hidden files visible.
      "last-location-bar" = "ThunarLocationEntry";
      "misc-window-title-style" = "THUNAR_WINDOW_TITLE_STYLE_FULL_PATH_WITH_THUNAR_SUFFIX";
      "last-show-hidden" = true;
    };
  };
}
