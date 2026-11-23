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
      pkgs.systemd
    ];
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
    ];
    runtimeEnv.MEETING_NOTES_DIR = cfg.meeting.directory;
    text = builtins.readFile ./meeting.sh;
  };
in
{
  options.hakkabara.cli.workHelpers = {
    timer.enable = lib.mkEnableOption "`timer` command for desktop reminders via systemd user timers";

    meeting = {
      enable = lib.mkEnableOption "`meeting` command for local Markdown meeting notes";

      directory = lib.mkOption {
        type = lib.types.str;
        default = "${config.home.homeDirectory}/Notes/meetings";
        defaultText = lib.literalExpression ''"''${config.home.homeDirectory}/Notes/meetings"'';
        description = "Directory that holds the meeting notes.";
      };
    };
  };

  config.home.packages =
    lib.optional cfg.timer.enable timer ++ lib.optional cfg.meeting.enable meeting;
}
