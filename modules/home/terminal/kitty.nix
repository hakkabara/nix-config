{ pkgs, ... }:

{
  programs.kitty = {
    enable = true;

    font = {
      package = pkgs.nerd-fonts.fira-code;
      name = "FiraCode Nerd Font Mono";
      size = 12;
    };

    themeFile = "tokyo_night_night";

    shellIntegration = {
      enableZshIntegration = true;
      mode = "no-rc";
    };

    settings = {
      # Keep interactive history useful without using excessive RAM.
      scrollback_lines = 30000;

      # Deep history is kept separately and only passed to the scrollback pager.
      scrollback_pager_history_size = 100;

      # Mouse selection immediately enters the system clipboard.
      copy_on_select = "clipboard";
      strip_trailing_spaces = "smart";

      # Keep Kitty's paste-safety checks enabled.
      paste_actions = "quote-urls-at-prompt,confirm";

      # URL / OSC8 hyperlink handling.
      detect_urls = true;
      open_url_with = "default";
      url_style = "curly";
      underline_hyperlinks = "hover";
      show_hyperlink_targets = "ctrl";

      # Disable all bell/attention mechanisms.
      enable_audio_bell = false;
      visual_bell_duration = 0;
      window_alert_on_bell = false;
      bell_on_tab = "none";
      command_on_bell = "none";

      # Do not expose Kitty remote control by default.
      allow_remote_control = "no";

      update_check_interval = 0;
      # -----------------------------------------------------------------------
      # Window appearance
      # -----------------------------------------------------------------------

      # Remove the KDE/KWin title bar and outer OS window decorations.
      hide_window_decorations = true;

      # Slight transparency while keeping logs/code highly readable.
      background_opacity = "0.94";
      window_padding_width = 6;
      cursor_shape = "beam";
      cursor_blink_interval = 0;
    };

    keybindings = {
      # SurfVM clipboard convention.
      "ctrl+c" = "copy_to_clipboard";
      "ctrl+v" = "paste_from_clipboard";
      "ctrl+shift+c" = "send_key ctrl+c";
      "ctrl+shift+v" = "paste_from_clipboard";

      # Preserve Kitty's built-in Ctrl+Shift+P chords and add copy-oriented
      # DFIR/Admin hints only on currently-unused variants.

      # URL: lowercase y remains Kitty's built-in hyperlink action.
      "ctrl+shift+p>shift+y" = "kitten hints --type=url --program=@";
      "ctrl+shift+p>alt+y" = "kitten hints --type=url --program=@ --multiple --multiple-joiner=newline";

      # Hash: lowercase h remains Kitty's built-in insert-hash action.
      "ctrl+shift+p>shift+h" = "kitten hints --type=hash --program=@";
      "ctrl+shift+p>alt+h" = "kitten hints --type=hash --program=@ --multiple --multiple-joiner=newline";

      # IP addresses.
      "ctrl+shift+p>i" = "kitten hints --type=ip --program=@";
      "ctrl+shift+p>shift+i" = "kitten hints --type=ip --program=@ --multiple --multiple-joiner=newline";

      # CVE identifiers.
      "ctrl+shift+p>v" =
        "kitten hints --type=regex --regex=(?i)\\bCVE-[0-9]{4}-[0-9]{4,7}\\b --program=@";
      "ctrl+shift+p>shift+v" =
        "kitten hints --type=regex --regex=(?i)\\bCVE-[0-9]{4}-[0-9]{4,7}\\b --program=@ --multiple --multiple-joiner=newline";

      # MITRE ATT&CK technique/sub-technique IDs (T1059 / T1059.001).
      "ctrl+shift+p>m" =
        "kitten hints --type=regex --regex=(?i)\\bT[0-9]{4}(\\.[0-9]{3})?(?![.0-9]) --program=@";
      "ctrl+shift+p>shift+m" =
        "kitten hints --type=regex --regex=(?i)\\bT[0-9]{4}(\\.[0-9]{3})?(?![.0-9]) --program=@ --multiple --multiple-joiner=newline";

      # UUIDs.
      "ctrl+shift+p>u" =
        "kitten hints --type=regex --regex=(?i)\\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\\b --program=@";
      "ctrl+shift+p>shift+u" =
        "kitten hints --type=regex --regex=(?i)\\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\\b --program=@ --multiple --multiple-joiner=newline";

      # MAC addresses.
      "ctrl+shift+p>a" =
        "kitten hints --type=regex --regex=(?i)\\b([0-9a-f]{2}[:-]){5}[0-9a-f]{2}\\b --program=@";
      "ctrl+shift+p>shift+a" =
        "kitten hints --type=regex --regex=(?i)\\b([0-9a-f]{2}[:-]){5}[0-9a-f]{2}\\b --program=@ --multiple --multiple-joiner=newline";
    };
  };
}
