{
  config,
  lib,
  pkgs,
  pkgsUnstable,
  ...
}:

let
  cfg = config.hakkabara.terminal;
in
{
  config = lib.mkIf (cfg.enable && cfg.zellij.enable) {
    # xclip is used by Zellij to write directly to the X11 system clipboard.
    home.packages = [
      pkgs.xclip
    ];

    programs.zellij = {
      enable = true;

      # Zellij moves faster than the NixOS stable package set.
      #
      # Only Zellij opts into nixos-unstable; the rest of the terminal
      # environment continues to use the stable `pkgs` package set.
      package = pkgsUnstable.zellij;

      # Zellij should be started explicitly, not automatically for every Zsh.
      enableZshIntegration = false;

      settings = {
        # -----------------------------------------------------------------------
        # Appearance
        # -----------------------------------------------------------------------

        theme = "tokyo-night";
        default_layout = "compact";

        # Keep pane borders for orientation.
        pane_frames = true;

        # -----------------------------------------------------------------------
        # Mouse / history
        # -----------------------------------------------------------------------

        mouse_mode = true;
        scroll_buffer_size = 250000;

        # -----------------------------------------------------------------------
        # Clipboard
        # -----------------------------------------------------------------------

        # Zellij pipes the selected text to xclip.
        # This bypasses the OSC52 issue we observed with Kitty/X11.
        copy_command = "xclip -selection clipboard";

        # Copy as soon as the mouse selection is released.
        copy_on_select = true;

        # -----------------------------------------------------------------------
        # Sessions
        # -----------------------------------------------------------------------

        on_force_close = "detach";

        # Save enough metadata to resurrect the session structure.
        session_serialization = true;

        # Do NOT persist visible terminal contents to disk.
        pane_viewport_serialization = false;

        serialization_interval = 60;

        show_startup_tips = true;
        show_release_notes = false;

        # -----------------------------------------------------------------------
        # Terminal capabilities
        # -----------------------------------------------------------------------

        osc8_hyperlinks = true;
        support_kitty_keyboard_protocol = true;

        visual_bell = false;

        # -----------------------------------------------------------------------
        # Web functionality
        # -----------------------------------------------------------------------

        web_server = false;
      };
    };
  };
}
