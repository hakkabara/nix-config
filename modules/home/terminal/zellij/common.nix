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
    # Clipboard support shared by every Zellij profile.
    home.packages = [
      pkgs.xclip
    ];

    programs.zellij = {
      enable = true;

      # Zellij moves faster than the stable NixOS package set.
      # Only Zellij opts into nixos-unstable.
      package = pkgsUnstable.zellij;

      # Start Zellij explicitly rather than wrapping every interactive shell.
      enableZshIntegration = false;

      settings = {
        # ---------------------------------------------------------------------
        # Appearance
        # ---------------------------------------------------------------------

        theme = "tokyo-night";

        # zjstatus owns our custom default layout. If it is disabled, fall
        # back to Zellij's built-in compact layout so no dead plugin reference
        # remains.
        default_layout =
          if cfg.zellij.plugins.zjstatus.enable then
            "default"
          else
            "compact";

        pane_frames = true;

        # ---------------------------------------------------------------------
        # Mouse / history
        # ---------------------------------------------------------------------

        mouse_mode = true;
        scroll_buffer_size = 250000;

        # ---------------------------------------------------------------------
        # Clipboard
        # ---------------------------------------------------------------------

        # Direct X11 clipboard writes avoid the Kitty/X11 OSC52 issue observed
        # on the SurfVM.
        copy_command = "xclip -selection clipboard";
        copy_on_select = true;

        # ---------------------------------------------------------------------
        # Sessions
        # ---------------------------------------------------------------------

        on_force_close = "detach";

        session_serialization = true;

        # Never persist visible terminal contents to disk.
        pane_viewport_serialization = false;

        serialization_interval = 60;

        show_startup_tips = true;
        show_release_notes = false;

        # ---------------------------------------------------------------------
        # Terminal capabilities
        # ---------------------------------------------------------------------

        osc8_hyperlinks = true;
        support_kitty_keyboard_protocol = true;
        visual_bell = false;

        # ---------------------------------------------------------------------
        # Web functionality
        # ---------------------------------------------------------------------

        web_server = false;
      };
    };
  };
}
