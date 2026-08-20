{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hakkabara.terminal;
in
{
  config = lib.mkIf (cfg.enable && cfg.tmux.enable) {
    programs.tmux = {
      enable = true;

      shell = "${pkgs.zsh}/bin/zsh";
      terminal = "tmux-256color";

      # Keep standard Ctrl+B prefix by intentionally not setting prefix/shortcut.
      baseIndex = 1;
      clock24 = true;
      escapeTime = 10;
      historyLimit = 250000;
      keyMode = "vi";
      mouse = true;
      focusEvents = true;
      secureSocket = true;

      plugins = with pkgs.tmuxPlugins; [
        tmux-fzf
        extrakto
        tmux-thumbs
        resurrect
        {
          plugin = tokyo-night-tmux;
          extraConfig = ''
            set -g @tokyo-night-tmux_theme night
            set -g @tokyo-night-tmux_transparent 0
            set -g @tokyo-night-tmux_show_datetime 1
            set -g @tokyo-night-tmux_date_format YMD
            set -g @tokyo-night-tmux_time_format 24H
          '';
        }
      ];

      extraConfig = ''
        set -g renumber-windows on

        # Export tmux copies through OSC52 while preventing child applications
        # from writing tmux buffers through OSC52 themselves.
        set -s set-clipboard external

        # Truecolor support when hosted in Kitty.
        set -as terminal-features ',xterm-kitty:RGB'

        # Silence tmux bell/activity notifications.
        set -g bell-action none
        set -g visual-bell off
        set -g visual-activity off
        setw -g monitor-bell off
        setw -g monitor-activity off

        # Keep the upstream c / " / % keys, only inherit the active pane cwd.
        bind c new-window -c "#{pane_current_path}"
        bind '"' split-window -v -c "#{pane_current_path}"
        bind % split-window -h -c "#{pane_current_path}"
      '';
    };
  };
}
