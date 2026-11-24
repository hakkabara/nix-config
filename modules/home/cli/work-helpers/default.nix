{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hakkabara.cli.workHelpers;

  timer = pkgs.writeShellApplication {
    name = "timer";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gawk
      pkgs.findutils
      pkgs.libnotify
      pkgs.pipewire
      pkgs.systemd
    ];
    runtimeEnv = {
      TIMER_SOUND = lib.optionalString cfg.timer.sound.enable cfg.timer.sound.file;
      TIMER_SOUND_VOLUME = cfg.timer.sound.volume;
    };
    text = builtins.readFile ./timer.sh;
  };

  meeting = pkgs.writeShellApplication {
    name = "meeting";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.gnused
      pkgs.fzf
      pkgs.bat
      pkgs.wl-clipboard
    ];
    runtimeEnv = {
      MEETING_NOTES_DIR = cfg.meeting.directory;
      MEETING_ATTENDEE = cfg.meeting.attendee;
    };
    text = builtins.readFile ./meeting.sh;
  };
in
{
  options.hakkabara.cli.workHelpers = {
    timer = {
      enable = lib.mkEnableOption "`timer` command for desktop reminders via systemd user timers";

      sound = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Play a short sound when a timer elapses.";
        };

        file = lib.mkOption {
          type = lib.types.str;
          default = "${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/complete.oga";
          defaultText = lib.literalExpression ''"''${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/complete.oga"'';
          description = "Sound file played with pw-play.";
        };

        volume = lib.mkOption {
          type = lib.types.str;
          default = "0.3";
          description = "pw-play volume (0.0-1.0); low by default.";
        };
      };
    };

    meeting = {
      enable = lib.mkEnableOption "`meeting` command for local Markdown meeting notes";

      directory = lib.mkOption {
        type = lib.types.str;
        default = "${config.home.homeDirectory}/Notes/meetings";
        defaultText = lib.literalExpression ''"''${config.home.homeDirectory}/Notes/meetings"'';
        description = "Directory that holds the meeting notes.";
      };

      attendee = lib.mkOption {
        type = lib.types.str;
        default = config.home.username;
        defaultText = lib.literalExpression "config.home.username";
        example = "";
        description = "Name a new note starts its attendee list with; empty for none.";
      };
    };
  };

  config.home.packages =
    lib.optional cfg.timer.enable timer ++ lib.optional cfg.meeting.enable meeting;
}
